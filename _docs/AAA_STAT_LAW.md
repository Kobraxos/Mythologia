# Loi de Statistiques AAA — Projet Mythologia

Ce document constitue la **norme architecturale** pour l'équilibrage du jeu. Toute création d'unité, de compétence ou d'objet doit se référer à cette échelle (Mid-Scale) afin de garantir la cohérence mathématique des affrontements.

## 1. L'Échelle de Référence (Standard Niveau 1)

Le jeu utilise des "grands nombres modérés" pour les Points de Vie et les Dégâts (permettant la granularité des buffs en pourcentage), tout en gardant des "petits nombres" pour l'économie d'action (lisibilité et stratégie).

*   **Points de Vie (PV) :** `~100` par unité standard (les Tanks tournent autour de 120-150, les fragiles autour de 60-80).
*   **Aegis (Bouclier) :** `0 à 50` selon le rôle. Agit comme une jauge de protection temporaire.
*   **Dégâts de Base (Auto-Attack) :** `~20 à 25`.
*   **Dégâts de Compétence :** `30 à 70` selon le coût de la compétence.

### Time To Kill (TTK)
Le jeu est conçu pour un TTK **Standard** :
*   Une unité classique (100 PV) doit mourir en **3 à 4 frappes basiques**.
*   Ou en **2 compétences puissantes**.

### Pourcentages et Modificateurs
Les statistiques comme la résistance (`res_fire`, `physical_defense`) ou l'esquive (`base_evasion`) utilisent des **pourcentages directs**.
*   *Exemple :* `base_evasion = 0.05` correspond à 5% de chance d'esquive.
*   Grâce aux dégâts tournant autour de 20+, un buff de `+15% dégâts` ajoute `3 dégâts`, ce qui est pris en compte et lisible par les entiers du système de combat.

---

## 2. L'Économie d'Action (Lisibilité Maximale)

*   **Points d'Action (PA) :** `3` à `4`. C'est le cœur du Tactical.
    *   Attaque basique : 2 PA.
    *   Sort lourd : 3 PA.
    *   Utilitaire/Déplacement mineur : 1 PA.
*   **Points de Mouvement (PM) :** `3` à `5` cases.
*   **Mana :** Échelle *x5* par rapport aux prototypes de base (`50 à 150` Mana max). Cela permet de créer des sorts coûtant 25, 50 ou 75 Mana, et d'intégrer plus tard des passifs de réduction de coût (ex: "-10% coût en mana").

---

## 3. Identité des Ressources : PV vs Aegis

Le Game Design différencie strictement la régénération des PV et celle de l'Aegis pour forcer le joueur à faire des choix tactiques :

*   **Aegis (Bouclier) :** 
    *   Conçu pour le *Hit & Run* et la gestion de couverture.
    *   **Régénération conditionnelle :** L'Aegis se régénère rapidement (10-20 par tour), mais **souffre d'un délai (`shield_regen_delay`)**. Si l'unité prend N'IMPORTE QUEL dégât direct, la régénération s'arrête net. Il faut cacher l'unité pendant 1 tour pour que la régénération reprenne.
*   **Points de Vie (PV) :**
    *   Conçus pour représenter les blessures graves.
    *   **Pas de régénération naturelle (ou très rare) :** Les unités standard et les héros ne régénèrent PAS leurs PV passivement (`hp_regen_per_turn = 0`). Seuls de rares passifs (ex: Sang de Troll) ou les Soigneurs (Healers) peuvent restaurer les PV.
    *   *(Note d'architecture : La regen PV, quand elle existe, ne s'arrête pas sous les dégâts. Elle tourne à chaque tour).*
