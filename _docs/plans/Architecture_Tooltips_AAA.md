# 🪐 Plan d'Architecture AAA : Système de Tooltips Dynamiques

Ce document détaille la manière dont un jeu AAA (tactique ou RPG) gère l'affichage des informations au survol (compétences, statuts, objets), en évitant les limites du système de base de Godot.

## 1. Pourquoi ne pas utiliser le `tooltip_text` natif de Godot ?
La propriété native `tooltip_text` des nœuds `Control` est beaucoup trop limitée pour un jeu professionnel :
- Elle ne supporte que du texte brut (pas d'icônes, pas de mise en page riche, pas de couleurs dynamiques).
- Le délai d'apparition est global et rigide.
- L'apparence de la boîte est difficilement personnalisable de façon complexe (ex: afficher le coût en PA à droite du titre, et une bordure dorée pour les sorts ultimes).

## 2. Le Modèle AAA : Le `TooltipManager` (Singleton / CanvasLayer)

La règle d'or dans la création d'UI : **Une interface locale ne doit jamais instancier de popup globale qui déborde de son espace.**
Si un `SkillButton` instancie son propre tooltip comme un nœud enfant, ce tooltip risque d'être coupé (clippé) par les bords du conteneur parent (comme un `ScrollContainer` ou un panneau `Clip Contents = true`).

### A. Le Nœud Global (`autoloads/tooltip_manager.gd`)
On crée un Autoload `TooltipManager` qui hérite de `CanvasLayer` (avec un `layer` très élevé, ex: `100`).
Cela garantit que les tooltips s'afficheront **absolument toujours au-dessus du reste du jeu**.

### B. Couplage Faible (Event-Driven)
Le `SkillButton` ne connaît pas le design du tooltip. Ses seules responsabilités sont :
1. Détecter le survol (`mouse_entered`).
2. Détecter la sortie (`mouse_exited`).
3. Appeler le manager global.

```gdscript
func _on_mouse_entered() -> void:
    TooltipManager.show_tooltip(_skill, global_position, size)

func _on_mouse_exited() -> void:
    TooltipManager.hide_tooltip()
```

## 3. Contenu Polymorphe et Data-Driven

Le `TooltipManager` instancie (ou réutilise, via un pool) une scène générique `tooltip_panel.tscn`. 
Ce panneau est capable de "lire" n'importe quelle ressource (`Resource`).

```gdscript
func show_tooltip(data: Resource, source_pos: Vector2, source_size: Vector2) -> void:
    if data is SkillData:
        _build_skill_tooltip(data)
    elif data is StatusData:
        _build_status_tooltip(data)
    # ...
```

Un "Skill Tooltip" se construira avec :
- Un `HBoxContainer` pour le Titre (gauche) et les coûts en AP/MP (droite, avec des icônes).
- Un `RichTextLabel` pour la description (qui permet les balises BBCode pour colorer les mots clés comme "[color=red]Dégâts[/color]").
- Un `Label` optionnel pour le Cooldown.

## 4. Smart Positioning (Le "Screen Clamping")

C'est la marque d'un jeu fini : le tooltip ne doit **jamais** sortir de l'écran. 
Le `TooltipManager` doit calculer mathématiquement sa position :
1. Il se place généralement au-dessus ou sur le côté du bouton survolé (grâce au `source_pos` et `source_size`).
2. Il utilise `get_viewport_rect().size` pour vérifier si la boîte du tooltip dépasse de l'écran.
3. Si ça dépasse à droite, il se décale à gauche. Si ça dépasse en haut, il se décale en bas.

## 5. Résumé des tâches pour l'implémentation (Demain)

- [ ] **1.** Créer la scène UI `tooltip_panel.tscn` (VBoxContainer propre, avec polices et thème AAA).
- [ ] **2.** Créer l'Autoload `TooltipManager` (CanvasLayer) et l'ajouter à `project.godot`.
- [ ] **3.** Implémenter la logique de _Smart Positioning_ (Screen clamp).
- [ ] **4.** Modifier `skill_button.gd` pour émettre les signaux `mouse_entered` et `mouse_exited`.
- [ ] **5.** (Optionnel) Ajouter un micro-délai (Timer de 0.2s) dans le manager pour éviter que le tooltip ne "flash" si le joueur traverse l'écran rapidement avec sa souris.
