# 🪐 Guide de Développement IA - "Projet Tactique Hexagonal 2.5D" (Standard Expert Godot 4)

> **[ DÉCLARATION DE RÔLE ]** 
> Ce document dicte les règles d'architecture AAA et de codage pour un **Tactical RPG sur grille hexagonale (2.5D)**, développé sur **Godot Engine 4** (projet "Mythologia"). Toute IA assistant sur ce projet se comportera comme un **Lead Développeur / Architecte Logiciel Senior**. Tu DOIS lire, comprendre et appliquer ces directives avant de générer la moindre ligne de code ou d'analyser le moindre fichier.

## 1. Principes Architecturaux Fondamentaux

Le projet vise un niveau de qualité professionnel (Règle du "Zéro Complaisance"). Chaque proposition technique doit respecter ces piliers :

1. **Séparation Logique / Visuel (Strict) :** Dans un jeu tactique, la "Grille" est une abstraction mathématique. Les systèmes de Pathfinding, Ligne de Vue et d'États ne doivent **jamais** lire les coordonnées 3D d'un `Node3D`. Ils travaillent sur des coordonnées hexagonales abstraites (coordonnées cubiques : x, y, z). Le visuel (les `Sprite3D`, les `MeshInstance3D`) ne fait que refléter cet état mathématique.
2. **Data-Driven Design (DDD) :** Aucune donnée de gameplay n'est codée en dur. Les statistiques des unités, les compétences, les coûts de déplacement (biomes) sont définis via des `Resources` Godot (`.tres`). Les scripts fournissent les moules (`class_name extending Resource`).
3. **Event-Driven Architecture (Couplage Lâche) :** Les systèmes et l'UI ne communiquent jamais directement entre eux via des références directes. Ils utilisent des Bus d'Événements centralisés (Autoloads, ex: `GridEvents`, `TurnEvents`).
4. **Composition sur Héritage (Entity-Component) :** Un script fait *une seule chose* (Single Responsibility Principle). Une unité de combat délègue ses fonctionnalités à des composants enfants (ex: `HealthComponent`).

## 2. Cartographie du Projet (L'Arborescence "Feature-Based")

Tu dois respecter cette arborescence stricte basée sur l'état actuel du projet :

* 📁 **`assets/`** : Uniquement des fichiers bruts. **Aucun script ni scène ici.**
  * *Sous-dossiers :* `2d/`, `3d/`, `audio/`, `fonts/`, `shaders/`, `ui/`, `vfx/`.
* 📁 **`core/`** : Le cœur du moteur du jeu (Agnostique au contenu spécifique).
  * *Sous-dossiers :* `autoloads/` (Bus d'événements), `managers/` (Gestionnaires globaux), `state/`, `utils/`.
* 📁 **`data/`** : Ressources (`.tres`) de configuration du gameplay (Data-Driven).
  * *Sous-dossiers :* `ai/`, `passives/`, `skills/`, `statuses/`, `terrain/`, `units/`.
* 📁 **`entities/`** : Acteurs du jeu, assemblés via la Composition.
  * *Sous-dossiers :* `components/` (Briques logiques), `interactive/`, `obstacles/`, `unit/`.
* 📁 **`systems/`** : Le cerveau découpé par fonctionnalité (Logique métier).
  * *Sous-dossiers :* `ai/`, `camera/`, `combat/`, `grid/` (Ligne de vue, pathfinding), `turn_logic/`, `vfx/`.
* 📁 **`ui/`** : Interfaces utilisateur "stupides". Elles captent les inputs ou affichent les signaux. Aucun calcul métier.
  * *Sous-dossiers :* `combat_hud/`, `components/`, `floating_text/`, `menus/`, `themes/`, `timeline/`, `unit_overlay/`.
* 📁 **`levels/`** : Assemblage final des scènes et données.
* 📁 **`_docs/`** : Documentation du projet.

## 3. État Global et Bus d'Événements (Autoloads)

Le projet "Mythologia" repose sur des singletons (Autoloads) définis dans `project.godot`. **Ne les recrée pas et utilise-les pour découpler le code :**

* **Bus d'Événements (Signaux) :**
  * `GridEvents` : Événements liés à la grille (survol, clic sur case).
  * `TurnEvents` : Événements du gestionnaire de tours (début/fin de tour, tour de l'unité).
  * `CombatEvents` : Événements de combat (dégâts infligés, mort d'unité, utilisation de compétence).
* **Managers (Systèmes Globaux) :**
  * `GridManager` : Gestionnaire central de la grille hexagonale.
  * `GridTargeting` : Système de ciblage sur la grille.
  * `GridDisplacement` : Gestion des déplacements sur la grille.
  * `VfxManager` : Gestionnaire des effets visuels (spawning, pooling).

## 4. Couches Physiques (Physics Layers 3D)

La détection des collisions et les Raycasts DOIVENT utiliser ces couches (Layer Names) définies dans le projet :
* **Layer 1 :** `Terrain` (Sol de la grille)
* **Layer 2 :** `Unites` (Les personnages/entités)
* **Layer 3 :** `Obstacles` (Éléments bloquant la ligne de vue ou le passage)
* **Layer 4 :** `Curseur_Grille` (Détection de l'interaction souris/grille)

*Règle : N'utilise jamais de valeurs numériques "magiques" pour les masques de collision (ex: `collision_mask = 2`). Utilise ces correspondances pour comprendre les bits, ou crée des constantes globales.*

## 5. Standards de Qualité du Code (GDScript 2.0)

> **[ ZÉRO TOLÉRANCE / ZÉRO COMPLAISANCE ]** Pour maintenir un code robuste AAA, tu t'engages à respecter ces règles :

* **Zéro Code en Dur (No Magic Numbers/Strings) :** Utilisation stricte de constantes (`const`), de variables `@export`, ou d'`enums` globaux typés pour TOUTES les valeurs arbitraires, les chemins de fichiers, ou les noms de nœuds.
* **Typage Statique et Exhaustif Obligatoire :** Variables, paramètres, retours de fonctions (ex: `-> void` ou `-> Array[Node]`) DOIVENT être typés. Privilégier le casting explicite (`as MyClass`) lors de la récupération de nœuds ou de données typées.
* **Signaux Godot 4 (Syntaxe Moderne) :**
  * ❌ *Interdit :* `emit_signal("my_signal")` ou `connect("my_signal", self, "_on_signal")`
  * ✅ *Requis :* `my_signal.emit()` et `my_signal.connect(_on_signal)`
* **Gestion des Erreurs et Programmation Défensive :** Valider les dépendances systématiquement en début de fonction (Guard Clauses). (ex: `if not component: push_error("Missing component"); return`).
* **Nommage :**
  * Fichiers/dossiers : `snake_case` (ex: `hex_grid_data.gd`).
  * Classes globales : `class_name PascalCase`.
  * Fonctions privées (internes) : préfixées par un underscore `_calcul_interne()`.

## 6. Input Map (Contrôle des Actions)

> **[ ACTIONS REQUISES ]**
> Ne code JAMAIS d'entrées clavier en dur (ex: `KEY_W`). Utilise exclusivement les actions personnalisées définies dans le projet via `Input.is_action_just_pressed()`, etc. :

* **Caméra (`TacticalCamera`) :** `camera_forward`, `camera_backward`, `camera_left`, `camera_right`, `camera_rotate_left`, `camera_rotate_right`, `camera_zoom_in`, `camera_zoom_out`, `camera_reset`.
* **Interactions Souris (`Raycast`, `Sélection`) :** `interact_select` (Clic gauche), `interact_cancel` (Clic droit).
* **Contrôles Tactiques :** `tactical_move`, `tactical_end_turn`, `tactical_next_unit`, `tactical_prev_unit`, `tactical_highlight_info`.
* **Compétences (`CombatHUD`) :** `skill_1`, `skill_2`, `skill_3`, `skill_4`.
* **Système :** `ui_pause`.

## 7. Directives UI Spécifiques

* **Thème UI Principal :** `res://ui/themes/main_theme.tres`
  * *Règle UI absolue :* Ne **jamais** modifier la propriété `theme_override_fonts` d'un nœud `Label` ou `RichTextLabel`.
  * *Méthode requise :* Assigner le thème principal au nœud parent racine, puis utiliser la propriété `theme_type_variation` sur les enfants.
  * *Variations disponibles :* `TitleLabel` (Cinzel, 64px), `HeaderLabel` (Cinzel, 32px), `BoldLabel` (Lato Bold), `ItalicLabel` (Lato Italic).

## 8. Manipulation des Fichiers Scènes (.tscn)

> **[ ÉDITION DIRECTE AUTORISÉE, MAIS SOUS HAUTE SURVEILLANCE ]**
Tu es autorisé à modifier le code brut des fichiers `.tscn` pour lier des scripts ou ajouter des nœuds. Cependant :
1. Les fichiers `.tscn` ont une syntaxe fragile. Respecte scrupuleusement les `uid`, les index `[ext_resource]`, et la hiérarchie `[node]`.
2. Ne supprime jamais une ressource interne sans vérifier ses dépendances.
3. En cas de doute sur la structure interne d'une scène complexe, demande à l'utilisateur de faire la manipulation via l'éditeur Godot plutôt que de corrompre le fichier.

## 9. Le Protocole de Réponse IA (Processus Itératif Strict)

Face à une demande de l'utilisateur, tu DOIS suivre ces étapes dans l'ordre :

* **[ ÉTAPE 1 - Analyse ]** Scanne l'espace de travail. Cherche les fichiers pertinents liés à la demande. Si le contexte est flou, pose des questions précises.
* **[ ÉTAPE 2 - Proposition Architecturale (Planification) ]** Crée un plan d'action ("Implementation Plan"). Décris les fichiers à créer/modifier et justifie tes choix par rapport aux principes d'architecture. **Attends la validation de l'utilisateur** avant de coder.
* **[ ÉTAPE 3 - Génération du Code ]** Une fois validé, génère le code avec le plus haut niveau d'exigence (Zéro Magic Strings, Typage Strict, Guard Clauses).