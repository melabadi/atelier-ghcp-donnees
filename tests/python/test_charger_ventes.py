"""Tests de comportement de la procédure réelle; aucune émulation de T-SQL."""

from decimal import Decimal

import pyodbc
import pytest

from conftest import requete


def charger(cur):
    return cur.execute(requete("charger")).fetchone()[0]


def test_conversion_resolution_et_sortie(curseur):
    assert charger(curseur) == 2
    lignes = [tuple(ligne) for ligne in curseur.execute(requete("ventes")).fetchall()]
    assert lignes == [
        ("PY-001", "CLI-001", "PRD-001", 2, Decimal("18.50"), Decimal("37.00"), "2024-01-03"),
        ("PY-002", "CLI-002", "PRD-002", 3, Decimal("21.00"), Decimal("63.00"), "2024-02-05"),
    ]


@pytest.mark.parametrize(
    "date,client,produit,quantite,prix,numero",
    [
        ("date-invalide", "CLI-001", "PRD-001", "1", "10", "PY-INVALIDE"),
        ("2024-01-01", "CLI-999", "PRD-001", "1", "10", "PY-INVALIDE"),
        ("2024-01-01", "CLI-001", "PRD-999", "1", "10", "PY-INVALIDE"),
        ("2024-01-01", "CLI-001", "PRD-001", "texte", "10", "PY-INVALIDE"),
        ("2024-01-01", "CLI-001", "PRD-001", "1", "texte", "PY-INVALIDE"),
        ("2024-01-01", "CLI-001", "PRD-001", "1", "10", None),
    ],
)
def test_exclut_ligne_non_chargeable(curseur, date, client, produit, quantite, prix, numero):
    curseur.execute(requete("inserer"), numero, date, client, produit, quantite, prix)
    assert charger(curseur) == 2


def test_source_vide(curseur):
    curseur.execute(requete("vider_source"))
    assert charger(curseur) == 0
    assert curseur.execute(requete("compter")).fetchone()[0] == 0


def test_contrat_relance_explicite(curseur, pytestconfig):
    assert charger(curseur) == 2
    idempotent = pytestconfig.getoption("--contrat-relance") == "idempotent"
    assert charger(curseur) == (0 if idempotent else 2)
    assert curseur.execute(requete("compter")).fetchone()[0] == (2 if idempotent else 4)


@pytest.mark.parametrize("quantite,prix", [("0", "10"), ("1", "-1")])
def test_erreur_contrainte_annule_tout(curseur, quantite, prix):
    curseur.execute(requete("inserer"), "PY-ERREUR", "2024-01-01", "CLI-001", "PRD-001", quantite, prix)
    with pytest.raises(pyodbc.IntegrityError) as erreur:
        charger(curseur)
    assert "547" in str(erreur.value)
    assert curseur.execute(requete("etat_transaction")).fetchone()[0] == 0
    assert curseur.execute(requete("compter")).fetchone()[0] == 0
