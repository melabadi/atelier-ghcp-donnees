"""Chronométrage client et analyse descriptive du plan réel, sans verdict de production."""

from collections import Counter
import json
import math
import platform
import statistics
import time
import xml.etree.ElementTree as ET

import pytest

from conftest import requete
from test_charger_ventes import charger

NS = {"p": "http://schemas.microsoft.com/sqlserver/2004/07/showplan"}


def analyser_plan(xml):
    racine = ET.fromstring(xml)
    if racine.tag != f"{{{NS['p']}}}ShowPlanXML":
        raise ValueError("Résultat différent d'un ShowPlanXML")
    operateurs = []
    for noeud in racine.findall(".//p:RelOp", NS):
        compteurs = noeud.findall("./p:RunTimeInformation/p:RunTimeCountersPerThread", NS)
        operateurs.append({
            "node_id": noeud.get("NodeId"),
            "physique": noeud.get("PhysicalOp"),
            "logique": noeud.get("LogicalOp"),
            "lignes_estimees": float(noeud.get("EstimateRows", "0")),
            "lignes_reelles": sum(float(c.get("ActualRows", "0")) for c in compteurs),
            "executions_reelles": sum(int(c.get("ActualExecutions", "0")) for c in compteurs),
            "compteurs_presents": bool(compteurs),
        })
    return {
        "operateurs": operateurs,
        "types_operateurs": dict(Counter(o["physique"] for o in operateurs)),
        "avertissements": [
            ET.tostring(n, encoding="unicode") for n in racine.findall(".//p:Warnings", NS)
        ],
        "index_suggeres": [
            ET.tostring(n, encoding="unicode") for n in racine.findall(".//p:MissingIndexes", NS)
        ],
    }


@pytest.mark.performance
def test_latence_et_plan(curseur, configuration_performance):
    config = configuration_performance
    curseur.execute(requete("volume"), config["lignes"])
    version = curseur.execute(requete("version")).fetchone()[0]
    echantillons = []
    for i in range(config["repetitions"] + 2):
        curseur.execute(requete("vider_cible"))
        debut = time.perf_counter_ns()
        nombre = charger(curseur)
        duree = (time.perf_counter_ns() - debut) / 1_000_000
        assert nombre == config["lignes"]
        if i >= 2:
            echantillons.append(duree)
    p95 = sorted(echantillons)[math.ceil(len(echantillons) * 0.95) - 1]
    mesures = {
        "scenario": "chargement initial, cache réchauffé, transaction externe annulée",
        "sql_server": version,
        "python": platform.python_version(),
        "lignes": config["lignes"],
        "echauffements": 2,
        "repetitions": config["repetitions"],
        "echantillons_ms": echantillons,
        "mediane_ms": statistics.median(echantillons),
        "p95_ms": p95,
        "min_ms": min(echantillons),
        "max_ms": max(echantillons),
        "budget_p95_ms": config["budget_p95_ms"],
    }
    curseur.execute(requete("vider_cible"))
    plans = []
    curseur.execute(requete("activer_plan"))
    try:
        curseur.execute(requete("charger"))
        while True:
            if curseur.description:
                for ligne in curseur.fetchall():
                    if isinstance(ligne[0], str) and "ShowPlanXML" in ligne[0]:
                        plans.append(ligne[0])
            if not curseur.nextset():
                break
    finally:
        curseur.execute(requete("desactiver_plan"))
    assert plans, "Aucun plan réel retourné; vérifier les permissions SHOWPLAN"
    analyses = []
    for i, xml in enumerate(plans, 1):
        (config["rapport"] / f"chargement-{i}.sqlplan").write_text(xml, encoding="utf-8")
        analyses.append(analyser_plan(xml))
    assert any(o["compteurs_presents"] for a in analyses for o in a["operateurs"])
    mesures["plans"] = analyses
    fichier = config["rapport"] / "mesures.json"
    fichier.write_text(json.dumps(mesures, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"\nLatence : médiane={mesures['mediane_ms']:.2f} ms; p95={p95:.2f} ms; "
          f"{config['lignes']} lignes; résultats={fichier}")
    print("Plan réel :", [a["types_operateurs"] for a in analyses])
    if config["budget_p95_ms"] is not None:
        assert p95 <= config["budget_p95_ms"], f"p95 {p95:.2f} ms dépasse le budget configuré"
