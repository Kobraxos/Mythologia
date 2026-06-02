# Charte Architecturale & Standards de Développement
**Projet : Les 7 Mondes - Tactical Game**

Ce document définit les standards de code et d'architecture pour garantir un développement robuste, maintenable et évolutif (Standards type AAA) sur Godot 4.6+.

---

## 1. Principes Fondamentaux (Philosophie)

- **Séparation des Préoccupations (MVC/MVP) :** Ne jamais mélanger la logique métier (Règles du jeu, Stats, Grille mathématique) avec la représentation visuelle (Modèles 3D, UI, Animations).
- **Composition > Héritage :** Préférer construire des entités complexes en assemblant des petits composants (Nœuds Godot ou `Resource`) plutôt qu'en créant de longues chaînes d'héritage.
- **Single Responsibility Principle (SRP) :** Un script / un nœud ne doit faire qu'une seule chose. (ex: Le `GridController` gère l'état, l'A* gère le pathfinding).
- **KISS (Keep It Simple, Stupid) :** Ne pas over-engineerinér avant que le besoin n'existe.

---

## 2. Architecture Globale du Tactical

L'architecture doit s'appuyer sur trois piliers distincts pour le système de grille :

### A. Les Données (Model / Core)
- **`GridData` / `HexMetrics` :** Contient la logique mathématique (coordonnées axiales `Vector2i`, cubiques `Vector3i`), le stockage des tuiles et le Pathfinding (A*). *Ne connaît aucun nœud 3D.*
- **Système de Combat :** Calcul des dégâts, portées, ligne de vue (Line of Sight).
- **Ressources (`Resource`) :** Utiliser les `CustomResources` de Godot pour définir les statistiques des unités, les compétences (Skills), et les types de terrain.
- **Performances (Scale AAA) :** Le Core (Pathfinding, algorithmes de champ de vision) doit être suffisamment isolé pour pouvoir être migré en **C# ou C++ (GDExtension)** si les calculs GDScript deviennent limitants sur de très grandes cartes avec beaucoup d'IA.

### B. Le Contrôle (Controller)
- **State Machines :** Gérer le flot du jeu et les entités complexes (comme initié avec `ControllerState`). Un état = Un script.
- **GameManager / TurnManager :** Gère l'ordre des tours, donne la main au joueur ou à l'IA.
- **Input Manager :** Centralise les inputs (clic souris, raccourcis) et les envoie au contrôleur actif (ex: `GridController`).

### C. La Vue (View)
- **`GridView` / `UnitView` :** Gère uniquement l'affichage (Modèles 3D, particules, shaders de surbrillance).
- **UI (User Interface) :** Doit être complètement découplée. Elle ne lit que les données et réagit aux signaux.

---

## 3. Standards de Code (GDScript)

### Typage Strict (Static Typing)
- **Toujours typer** les variables, paramètres de fonctions et types de retours. Cela améliore l'autocomplétion, évite les bugs et optimise les performances de Godot 4.
  - *Oui :* `var health: int = 100`, `func get_path() -> Array[Vector2i]:`
  - *Non :* `var health = 100`, `func get_path():`

### Conventions de Nommage
- **Classes et Nœuds (`class_name`) :** `PascalCase` (ex: `GridController`, `TacticalUnit`).
- **Variables et Fonctions :** `snake_case` (ex: `current_state`, `calculate_damage()`).
- **Constantes :** `SCREAMING_SNAKE_CASE` (ex: `MAX_ACTION_POINTS`).
- **Signaux :** Utiliser des verbes au passé ou une action claire (ex: `unit_moved`, `turn_ended`, `on_attack_started`). *Nouveauté Godot 4.6 :* Utiliser un préfixe underscore (ex: `_internal_event`) pour masquer les signaux internes de l'autocomplétion des autres scripts.
- **Méthodes/Variables "Privées" :** Préfixer avec un underscore `_` pour indiquer qu'elles ne doivent pas être appelées de l'extérieur (ex: `_calculate_internal_stats()`).

### Documentation Intégrée (Docstrings)
- **Formatage Markdown :** Le LSP de Godot 4.6 gérant parfaitement le Markdown, toutes les fonctions publiques et variables exportées complexes doivent être documentées avec `##` en utilisant ce formatage (ex: `## Calcule le chemin vers **target** via [HexPathfinder]`).

### Structure d'un Script Standard
L'ordre des déclarations dans un fichier `.gd` doit toujours suivre cet ordre pour faciliter la lecture :
1. `class_name` et `extends`
2. Les `# SIGNALS`
3. Les `# ENUMS`
4. Les `# CONSTANTS`
5. Les `@export var` (Variables exposées dans l'inspecteur)
6. Les `var` publiques
7. Les `var` privées (préfixées par `_`)
8. Les `# GODOT BUILT-IN FUNCTIONS` (`_ready`, `_process`, `_unhandled_input`)
9. Les `# PUBLIC FUNCTIONS`
10. Les `# PRIVATE FUNCTIONS`
11. Les `# SIGNAL HANDLERS` (ex: `_on_button_pressed`)

---

## 4. Bonnes Pratiques Spécifiques à Godot

- **Event Bus (Signal Manager) :** Pour éviter le code "spaghetti", créer un Autoload `SignalBus.gd` ou `EventBus.gd` pour les événements globaux (ex: UI qui écoute la mort d'une unité sans référencer l'unité elle-même).
  - *Exemple :* `EventBus.unit_died.emit(unit_id)`
- **Éviter `get_node()` ou `$` absolus dans la logique complexe :** Préférer les `@export` pour brancher les dépendances via l'inspecteur (plus flexible si la hiérarchie change).
- **Gestion des Erreurs / Retours Anticipés (Guard Clauses) :** Éviter les indentations profondes (le "Arrow Code").
  - *Oui :*
    ```gdscript
    if not is_valid_target:
        return
    do_attack()
    ```
  - *Non :*
    ```gdscript
    if is_valid_target:
        do_attack()
    ```

---

## 5. Cœur du Jeu (Grille Hexagonale)

- **Coordonnées :** La source de vérité est la **coordonnée mathématique** (Axiale ou Cubique). Ne jamais se baser sur la position locale/globale `Transform3D` pour la logique.
- **Pathfinding A* :** Doit être isolé dans sa propre classe `HexPathfinder`, opérant uniquement sur un graphe de `Vector2i`.
- **Ligne de Vue (LoS) :** Séparer le calcul géométrique abstrait (ex: algorithme de Bresenham sur la grille) du Raycasting physique 3D. Godot 4.6 utilisant **Jolt Physics** par défaut, ce dernier assurera des performances optimales pour vos requêtes complexes de visibilité.

---

## 6. Structure du Projet (Arborescence)

L'organisation des dossiers du projet reflète la séparation des préoccupations définie ci-dessus :

- **`Assets/`** : Contient uniquement les fichiers bruts (Modèles 3D `.glb`, Sprites 2D, Audio, Fonts). *Aucun script ni scène complexe.*
- **`Data/`** : La base de données du jeu (Le "Model"). Contient toutes les ressources (`.tres`) définissant le gamedesign (Compétences, Stats des unités, Données de tuiles).
- **`Scenes/`** : L'assemblage visuel (La "Vue").
  - `Autoloads/` : Gestionnaires globaux et Event Busses (ex: `GridEvents`, `TurnEvents` s'ils sont instanciés ici).
  - `Entities/` : Pré-fabriqués des unités (ex: `unit.tscn`).
  - `Levels/` : Les niveaux complets et leurs composants (ex: `GridView.tscn`).
  - `UI/` : Interfaces utilisateur, complètement découplées de la logique métier.
- **`Scripts/`** : La logique métier (Les "Controllers" et le "Core").
  - `Core/` : L'intelligence centrale (Gestion des tours, IA, Caméra tactique).
    - `Grid/` : Toute la logique de grille (Data, Pathfinding, LoS, AoE, Controller).
    - `States/` : Les états de la machine à états de la grille (Idle, Move, Attack).
  - `Entities/` : Scripts de données et comportements individuels (ex: `Unit.gd`).
