"""Connexion à la base jetable détenue par valider.ps1, jamais à une base de démo."""

import math
import os
from pathlib import Path
import re
import uuid

import pyodbc
import pytest

SQL = Path(__file__).parent / "sql"


def requete(nom):
    return (SQL / f"{nom}.sql").read_text(encoding="utf-8-sig")


def pytest_addoption(parser):
    parser.addoption("--performance", action="store_true", help="Mesurer et capturer le plan réel")
    parser.addoption("--contrat-relance", choices=["doublons", "idempotent"], default="doublons")


def pytest_collection_modifyitems(config, items):
    if not config.getoption("--performance"):
        for item in items:
            if "performance" in item.keywords:
                item.add_marker(pytest.mark.skip(reason="Activer -PerformancePython dans valider.ps1"))


def valeur_positive(nom, defaut, entier=False):
    texte = os.environ.get(nom, str(defaut))
    valeur = int(texte) if entier else float(texte)
    if not math.isfinite(valeur) or valeur <= 0:
        raise ValueError(f"{nom} doit être positif et fini")
    return valeur


@pytest.fixture(scope="session")
def configuration_performance():
    repetitions = valeur_positive("PYTEST_REPETITIONS", 20, entier=True)
    if repetitions < 5:
        raise ValueError("PYTEST_REPETITIONS doit être >= 5")
    lignes = valeur_positive("PYTEST_LIGNES", 10000, entier=True)
    if lignes > 1_000_000:
        raise ValueError("PYTEST_LIGNES doit être <= 1000000 (capacité du scénario SQL)")
    budget = os.environ.get("PYTEST_P95_MAX_MS")
    rapport = Path(os.environ.get("PYTEST_RESULTATS", "resultats-python")) / uuid.uuid4().hex
    rapport.mkdir(parents=True)
    return {
        "lignes": lignes,
        "repetitions": repetitions,
        "budget_p95_ms": valeur_positive("PYTEST_P95_MAX_MS", budget) if budget else None,
        "rapport": rapport,
    }


@pytest.fixture(scope="session")
def connexion():
    base = os.environ.get("PYTEST_SQL_BASE", "")
    jeton = os.environ.get("PYTEST_SQL_JETON", "")
    if not re.fullmatch(r"[0-9a-f]{8}", jeton) or base != f"brulerie_val_{jeton}":
        raise RuntimeError("Lancer scripts/valider.ps1 : base jetable et jeton requis")
    pilote = os.environ.get("PYTEST_ODBC_DRIVER", "ODBC Driver 18 for SQL Server")
    if pilote not in pyodbc.drivers():
        raise RuntimeError(f"Pilote absent : {pilote}; configurer PYTEST_ODBC_DRIVER ou installer le pilote")

    def proteger(valeur):
        return "{" + valeur.replace("}", "}}") + "}"

    chaine = (
        f"DRIVER={proteger(pilote)};SERVER={proteger(os.environ['PYTEST_SQL_SERVEUR'])};"
        f"DATABASE={proteger(base)};Encrypt=yes;TrustServerCertificate=yes;"
    )
    auth = os.environ.get("PYTEST_SQL_AUTH")
    if auth == "windows":
        chaine += "Trusted_Connection=yes;"
    elif auth == "sql":
        chaine += (
            f"UID={proteger(os.environ['PYTEST_SQL_USER'])};"
            f"PWD={proteger(os.environ['PYTEST_SQL_PASSWORD'])};"
        )
    else:
        raise RuntimeError("PYTEST_SQL_AUTH doit valoir windows ou sql")
    # Désactiver le pool permet au propriétaire de supprimer la base après pytest.
    pyodbc.pooling = False
    cn = pyodbc.connect(chaine, autocommit=True, timeout=15)
    try:
        cn.timeout = 60
        marque = cn.execute(requete("propriete")).fetchone()
        if marque is None or marque[0] != jeton:
            raise RuntimeError("Base non détenue par ce lancement : tests refusés")
        yield cn
    finally:
        cn.close()


@pytest.fixture
def curseur(connexion):
    cur = connexion.cursor()
    try:
        cur.execute(requete("preparer"))
        yield cur
    finally:
        try:
            cur.execute(requete("annuler"))
        finally:
            cur.close()
