PROCHAINE ÉTAPE (AAA - Arrange/Act/Assert) :

1. Finaliser la couche "Model" manquante :

UnitStats.gd (Resource) → Définit les données des unités
Système de coûts de terrain (TerrainData.gd) → Coûts de déplacement par type de tuile
2. Compléter HighlightManager.gd (View):

Affichage des hexagones accessibles (vert)
Affichage de la portée d'attaque (rouge)
Sélection visuelle
3. Intégrer GridEvents.gd comme Autoload global (si absent)

Ordre recommandé :

Resources/Data (les "Arrange" du jeu)
HighlightManager (transforme les données en visuel)
GridGenerator complet (peuple la grille)