# 📋 AUDIT GÉNÉRAL — MYTHOLOGIA
> **Dernière mise à jour :** 07/06/2026 — Audit complet post-implémentation Aegis

**État Actuel :** Alpha Jouable — Architecture AAA solidifiée (~82% des systèmes core)

L'architecture est exceptionnellement solide pour cette phase : Event Bus, Composition Components, Resource DDD, Pipeline de dégâts complet, IA Utility, Pathfinding LRU. Le projet est prêt pour la phase Contenu.

---

## ✅ MILESTONES RÉCENTS (Complétés cette session)

| Feature | État | Détail |
| :--- | :--- | :--- |
| **Aegis dans les Compétences** | ✅ COMPLET | Pipeline de bouclier, grant_shield dynamique, combos |
| **Système d'Aegis (Bouclier)** | ✅ COMPLET | Absorption prioritaire, bypass_shield True Damage, regen + délai Protoss, UI ColorRect ambrée |
| **Shield Regen Delay** | ✅ COMPLET | `_shield_regen_cooldown` dans HealthComponent, fenêtre tactique après chaque coup |
| **Cache LRU Pathfinding** | ✅ COMPLET | `MAX_PATH_CACHE_SIZE = 3` dans HexPathfinder, éviction O(1) |
| **Race condition init overlay** | ✅ CORRIGÉ | Guard `current > 0` dans `_on_health_changed` — unités IA s'initialisent correctement |
| **HP_REGEN / SHIELD_REGEN via StatManager** | ✅ COMPLET | Buffs/debuffs sur les régénérations pleinement supportés |

---

## 🔴 CRITIQUE — Fonctionnalités déclarées MAIS non implémentées

> Ces champs existent dans les Resources (SkillData, StatusEffectData) mais **aucun système ne les lit au runtime**. Danger silencieux : le designer peut configurer ces valeurs sans résultat.

### SkillData — Champs orphelins
| Champ | Déclaré dans | Jamais lu par |
| :--- | :--- | :--- |
| ~~`flat_shield_granted`~~ | [skill_data.gd](file:///c:/Users/jacqu/OneDrive/Documents/mythologia/data/skills/skill_data.gd#L112) | ✅ Implémenté dans DamagePipeline |
| `contextual_scaling` + `scaling_factor` | [skill_data.gd](file:///c:/Users/jacqu/OneDrive/Documents/mythologia/data/skills/skill_data.gd#L103) | `DamagePipeline._process_damage()` — scaling dynamique (HP manquants, etc.) ignoré |
| ~~`follow_up_skill`~~ | [skill_data.gd](file:///c:/Users/jacqu/OneDrive/Documents/mythologia/data/skills/skill_data.gd#L71) | ✅ Implémenté dans CombatManager |
| `caster_movement` (DASH/LEAP/TELEPORT) | [skill_data.gd](file:///c:/Users/jacqu/OneDrive/Documents/mythologia/data/skills/skill_data.gd#L132) | `CombatManager` — le déplacement du lanceur n'est pas exécuté |
| `target_movement` (TELEPORT/SWAP) | [skill_data.gd](file:///c:/Users/jacqu/OneDrive/Documents/mythologia/data/skills/skill_data.gd#L130) | `CombatManager` — les téléportations de cible ne s'exécutent pas |
| `spawned_surface` | [skill_data.gd](file:///c:/Users/jacqu/OneDrive/Documents/mythologia/data/skills/skill_data.gd#L120) | `CombatManager` — les surfaces de terrain ne sont jamais instanciées |
| `destroys_terrain` | [skill_data.gd](file:///c:/Users/jacqu/OneDrive/Documents/mythologia/data/skills/skill_data.gd#L122) | `CombatManager` — destruction de terrain non implémentée |
| `summoned_entity` | [skill_data.gd](file:///c:/Users/jacqu/OneDrive/Documents/mythologia/data/skills/skill_data.gd#L136) | `CombatManager` — invocations non exécutées |
| `can_cast_via_proxy` | [skill_data.gd](file:///c:/Users/jacqu/OneDrive/Documents/mythologia/data/skills/skill_data.gd#L64) | `GridTargeting` — les Proxys ne sont jamais utilisés comme origine |
| `is_execution` | [skill_data.gd](file:///c:/Users/jacqu/OneDrive/Documents/mythologia/data/skills/skill_data.gd#L99) | `HealthComponent` — la mort définitive (no-resurrect) n'est pas marquée |

### StatusEffectData — Champs orphelins
| Champ | Déclaré dans | Jamais lu par |
| :--- | :--- | :--- |
| `triggers` (Array[StatusTriggerData]) | [status_effect_data.gd](file:///c:/Users/jacqu/OneDrive/Documents/mythologia/data/statuses/status_effect_data.gd#L55) | `StatusReceiverComponent` — aucun système d'événements réactifs n'est connecté |
| `activation_condition` | [status_effect_data.gd](file:///c:/Users/jacqu/OneDrive/Documents/mythologia/data/statuses/status_effect_data.gd#L30) | `StatusReceiverComponent._apply_new_status()` — condition jamais vérifiée |
| `stat_scaling` (MULTIPLY_BY_ELEVATION…) | [status_effect_data.gd](file:///c:/Users/jacqu/OneDrive/Documents/mythologia/data/statuses/status_effect_data.gd#L32) | `StatManagerComponent` — scaling contextuel ignoré |
| `is_untargetable` | [status_effect_data.gd](file:///c:/Users/jacqu/OneDrive/Documents/mythologia/data/statuses/status_effect_data.gd#L26) | `GridController` — les unités intangibles restent ciblables |
| `is_dispellable` | [status_effect_data.gd](file:///c:/Users/jacqu/OneDrive/Documents/mythologia/data/statuses/status_effect_data.gd#L24) | Aucun sort de dispel n'existe encore |
| `vfx_persistent` | [status_effect_data.gd](file:///c:/Users/jacqu/OneDrive/Documents/mythologia/data/statuses/status_effect_data.gd#L16) | `StatusReceiverComponent._apply_new_status()` — les auras visuelles ne s'attachent pas |
| `dot_element` | [status_effect_data.gd](file:///c:/Users/jacqu/OneDrive/Documents/mythologia/data/statuses/status_effect_data.gd#L51) | Les DoT passent par `take_damage()` sans élément — résistances élémentaires non appliquées aux DoT |

---

## 🟡 DETTE TECHNIQUE — À traiter avant la beta

### Performance
- [ ] **A\* Frontier O(n)** : `frontier.has(next_hex)` dans [hex_pathfinder.gd](file:///c:/Users/jacqu/OneDrive/Documents/mythologia/systems/grid/pathfinding/hex_pathfinder.gd#L151) est O(n). Remplacer par un `Dictionary[Vector3i, bool]` pour O(1). Impact : grilles 200+ hexes.
- [ ] **LoS Bresenham itératif** dans `grid_los_system.gd` — à refactoriser en Raycaster groupé 3D pour les AoE larges.

### TODO dans le code (annotations)
- [ ] [combat_sequencer.gd#L33](file:///c:/Users/jacqu/OneDrive/Documents/mythologia/systems/combat/sequencer/combat_sequencer.gd#L33) : `# TODO : Branchement vers le modèle 3D / AnimationPlayer` — les animations de sort ne jouent pas réellement.
- [ ] [tactical_camera.gd#L41](file:///c:/Users/jacqu/OneDrive/Documents/mythologia/systems/camera/tactical_camera.gd#L41) : `# TODO: Placeholder pour recentrer la caméra sur l'unité active` — la caméra ne suit pas l'unité active.

### Cohérence Shield ↔ DoT
- [ ] Les DoT dans `StatusReceiverComponent.apply_start_turn_effects()` appellent `take_damage()` **sans** `bypass_shield = true`. Décision à prendre : les DoT (poison, saignement) doivent-ils traverser le bouclier ou non ? Actuellement ils sont bloqués par l'Aegis, ce qui peut ne pas être voulu.

### BattleManager — Hardcodé
- [ ] [battle_manager.gd](file:///c:/Users/jacqu/OneDrive/Documents/mythologia/systems/combat/battle_manager.gd) spawn exactement 1 héros et 1 ennemi à des positions fixes. Aucun système de configuration de niveau.

---

## 🟢 PHASE CONTENU (Prochaines semaines)

### Contenu Data (Priorité absolue)
- [x] **3 monstres** dans `data/units/monsters/` — créés (Minotaure, Cyclope, Satyre)
- [x] **3 sorts** dans `data/skills/spells/` — créés (Charge, Oeil pétrifiant, Flèche)
- [ ] **1 seul niveau** (`test_room`) — créer 3-5 niveaux avec difficulté croissante
- [ ] **1 seul héros** (`base_unit_stats.tres`) sans nom, sans mythologie définie

### Systèmes de Contenu critiques (par ordre d'impact gameplay)
- [x] **`flat_shield_granted` dans le Pipeline** — connecter SkillData.flat_shield_granted à `health_component.restore_shield()` dans `_process_healing()`. Un sort de bouclier doit pouvoir accorder de l'Aegis.
- [x] **`follow_up_skill`** — après `_resolve_single_target()`, si `skill.follow_up_skill != null`, déclencher une seconde résolution centrée sur le même hex. Permet Frappe → AoE Ring en une seule compétence.
- [ ] **`contextual_scaling`** — lire `skill.contextual_scaling` dans `DamagePipeline._process_damage()` et appliquer le `scaling_factor` selon le cas (TARGET_MISSING_HP, ELEVATION_DIFFERENCE, etc.).
- [ ] **`caster_movement`** — implémenter DASH_TO_TARGET dans CombatManager (commande FORCED_MOVEMENT sur le lanceur avant l'impact).
- [ ] **Réactions élémentaires** (FIRE→Burn, ICE→Freeze, etc.) — `spawned_surface` et le pipeline élémentaire.
- [ ] **Formes AoE manquantes** : `RING` et `FLOOD_FILL` dans le système de ciblage.

### IA
- [ ] L'IA n'utilise jamais ses **compétences actives** (skills). Elle n'attaque qu'avec l'attaque de base.
- [ ] Pas de comportement de **fuite** quand HP < 25%.
- [ ] Pas d'**IA coopérative** (deux ennemis ne coordonnent pas leurs actions).

---

## 🔵 PHASE PRODUCTION AAA (Post-contenu)

### Polish Audiovisuel
- [ ] **Branchement AnimationPlayer** dans CombatSequencer — les sorts doivent jouer des animations 3D réelles.
- [ ] **VFX `visual_shield_broken`** — l'événement est émis mais aucun écouteur ne joue un VFX ou un SFX de brisure. Ajouter dans VfxManager.
- [ ] **VFX persistants des statuts** (`vfx_persistent` dans StatusEffectData) — les auras n'apparaissent pas sur les unités.
- [ ] **Caméra auto-focus** sur l'unité active (TODO déjà dans code).
- [ ] SFX pour actions de combat.
- [ ] Camera shake sur coups critiques.

### Système de Sauvegarde
- [ ] Snapshot de grille (toutes unités, statuts, rounds)
- [ ] Resume mid-battle + menu principal

### Tests & Stabilité
- [ ] Tests unitaires : `HexMath`, `HexPathfinder`, `DamagePipeline`
- [ ] Tests d'intégration : Combat end-to-end, Turn sequences
- [ ] Build release & profiling (cible 60 FPS min)

---

## ✅ SYSTÈMES CORE SOLIDES (Ne pas toucher)

| Système | Qualité | Notes |
| :--- | :--- | :--- |
| **Event Bus** (CombatEvents, GridEvents, TurnEvents) | ⭐⭐⭐⭐⭐ | Architecture parfaite, zéro couplage |
| **DamagePipeline** | ⭐⭐⭐⭐⭐ | Dodge, crit, résistances, armure, variance, soins |
| **HealthComponent** | ⭐⭐⭐⭐⭐ | HP + Aegis, bypass_shield, regen delay, tous signaux |
| **StatManagerComponent** | ⭐⭐⭐⭐⭐ | 9 stats bufables, formule AAA FLAT+PERCENT |
| **StatusReceiverComponent** | ⭐⭐⭐⭐ | MergeStrategy, CC, DoT/HoT, death prevent (triggers manquants) |
| **TurnManager** | ⭐⭐⭐⭐⭐ | Initiative, Stun skip, Timeline prédictive |
| **HexPathfinder** | ⭐⭐⭐⭐ | A\* + Cache LRU (frontier O(n) à corriger) |
| **GridController** | ⭐⭐⭐⭐⭐ | Ghost Stance, CC Guard, autorité spatiale |
| **UnitOverlay** | ⭐⭐⭐⭐⭐ | HP + Aegis (ColorRect dynamique), status icons, tweens |
| **VfxManager** | ⭐⭐⭐⭐ | Object Pooling, attachement dynamique |
| **AIControllerComponent** | ⭐⭐⭐ | Utility AI (2 actions, pas de compétences actives) |

---

## 📊 ROADMAP RECOMMANDÉE

| Semaine | Focus | Livrable |
| :--- | :--- | :--- |
| **W1** | ✅ Contenu Data : 3 monstres + 5 sorts de base | Combat avec diversité d'unités |
| **W2** | 🟡 `flat_shield_granted` + `follow_up_skill` + `contextual_scaling` | Sorts à effets multiples fonctionnels |
| **W3** | 🔴 `caster_movement` + AoE RING/FLOOD_FILL + Réactions élémentaires | Compétences tactiquement riches |
| **W4** | 🟡 3 niveaux de test + configuration BattleManager | 30 min de contenu jouable |
| **W5** | 🟡 IA Compétences actives + Comportement fuite | IA tactique crédible |
| **W6** | 🟡 AnimationPlayer + VFX Shield Break + SFX | Ressenti AAA |
| **W7** | 🔵 Triggers StatusEffect + Dispel + activation_condition | Système de statuts complet |
| **W8** | 🔵 Sauvegarde + Menu + Tests unitaires | Shippable |

---

## 🚀 PROCHAINE ÉTAPE IMMÉDIATE

**Implémenter le Scaling Contextuel (`contextual_scaling`)** : 
Actuellement, les dégâts sont statiques. L'objectif est d'implémenter les multiplicateurs dynamiques (TARGET_MISSING_HP, ELEVATION_DIFFERENCE) dans `DamagePipeline._process_damage()` pour enrichir la tactique (ex: Coup de grâce si cible blessée).

> **Objectif :** Ajouter une étape dans le calcul des dégâts qui lit l'enum `DamageScaling` de la compétence et applique le bonus au `base_amount`.