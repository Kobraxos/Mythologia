# Direction Artistique UI : "Mythologia"

Ce document centralise toutes les directives de style (Directives Artistiques, ou DA) pour l'interface utilisateur (HUD, Menus, Overlays) du projet *Mythologia*. 
Toute nouvelle interface doit scrupuleusement respecter ces principes pour garantir l'homogénéité AAA du titre.

## 1. Philosophie Générale
L'interface doit évoquer la grandeur, le mysticisme et la solidité de la Grèce Antique, tout en évitant de surcharger visuellement le joueur.
- **Ton** : Solennel, Divin, Épique, Lisible.
- **Thème Visuel Principal** : "Obsidienne et Or Antique". Les conteneurs ressemblent à des blocs de pierre polie sertis d'or.

## 2. Palette de Couleurs (Hex)
| Élément | Couleur Nom | Hex Code | Utilisation |
| :--- | :--- | :--- | :--- |
| **Fond (Panneaux)** | Obsidienne / Pierre Sombre | `#1A1A1A` ou `#23201D` | Fond des Action Bars, Portraits, Tooltips. |
| **Bordures & Accents** | Or Antique | `#D4AD35` ou `#D4A017` | Liserés, bordures des panneaux, textes importants, icônes divines. |
| **Points de Vie (PV)** | Rouge Sang | `#A52A2A` ou `#8B0000` | Barres de vie des unités. |
| **Points d'Action (PA)**| Jaune Solaire / Éclair | `#FFC800` ou `#F7CA18` | Gemmes de PA, icônes liées à l'action. |
| **Points de Mouvement (PM)** | Bleu Saphir / Céleste | `#59ABE3` ou `#1E90FF` | Gemmes de PM, icônes liées au déplacement. |
| **Désactivé / Inactif** | Gris Cendré | `#4A4A4A` ou `#5B5B5B` | Boutons grisés, compétences en cooldown. |

## 3. StyleBox & Conteneurs (Godot)
- **Bordures** : Asymétriques pour simuler le poids de la pierre (ex: Top/Left/Right: 2px, Bottom: 4px).
- **Corner Radius** : 
  - Standard : `4px` (Aspect pierre taillée, légèrement biseauté).
  - Exceptions : Cadre du Portrait (`40px` pour faire un cercle parfait), Gemmes (`10px`).
- **Ombres (Shadow)** : Présentes pour décoller l'UI de la grille 3D. Couleur `#000000` avec Alpha `0.6`. Offset vertical `(0, 4)`, Blur `4px`.

## 4. Composants Spécifiques

### 4.1. Le Cockpit (Bottom Console)
- **Architecture** : Divisée en 3 Piliers stricts. Ne se décale jamais. Disparaît totalement pendant le tour des IA.
- **Unit Frame (Gauche)** : Portrait circulaire cerclé d'or. Fine barre de vie Sang en dessous.
- **Action Bar (Centre)** : Plaque d'obsidienne rectangulaire avec liseré or.
- **Bouton Fin de Tour (Droite)** : Grand bouton rectangulaire élégant (`180x60`), texte majuscule "FIN DE TOUR" or sur obsidienne.

### 4.2. Barre de Ressources (ResourcePanel)
- **Concept** : Des Gemmes divines incrustées.
- **PA** : Diamants ou cercles dorés/solaires.
- **PM** : Saphirs ou cercles bleutés.
- **Design** : Les gemmes vides laissent apparaître un trou (cercle gris sombre/noir biseauté). Les gemmes pleines brillent.

### 4.3. Boutons de Compétences (Action Bar)
- **Forme** : Carrés stricts (ex: `64x64`).
- **Encadrement** : Bordure en or, fond en parchemin/pierre sombre. L'icône est au centre.
- **Action Déplacement (MoveButton)** : Suit exactement la même forme carrée que les sorts, mais trône obligatoirement à l'extrême gauche de la barre avec une icône de Pied ou d'Aile (Aile d'Hermès).

### 4.4. La Timeline (Initiative Tracker)
- **Placement** : En haut à droite de l'écran, s'étirant vers la gauche.
- **Effets (Shaders)** : Fond transparent avec shader de brume magique et poussières dorées.
- **Bordures** : Lignes lumineuses (Gradients) dorées qui s'estompent.

## 5. Typographie
- **Titres / Boutons Majeurs** : Style Sérif / Antique (ex: Cinzel, Trajan, ou polices similaires) avec Ombre Portée.
- **Textes de Tooltip** : Sans-Serif très lisible (ex: Inter, Roboto) pour ne pas fatiguer les yeux lors de la lecture des statistiques.
