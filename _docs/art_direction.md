# Direction Artistique : Mythologia

Ce document définit les piliers fondateurs de la Direction Artistique (DA) visuelle du jeu *Mythologia*.

## 1. Piliers Fondamentaux (2.5D Mythologique)
- **Personnages et Entités (2D) :** Les divinités, créatures et obstacles sont illustrés en 2D (haute résolution, style dessin/digital painting).
- **Environnement (3D) :** Les arènes et les décors sont modélisés en 3D.
- **Cohésion Visuelle :** La 3D adopte un rendu **Stylisé / "Hand-Painted"**. Les textures des modèles 3D (ou les shaders) sont pensées pour ressembler à de la peinture à la main, avec un ombrage doux. L'objectif est d'éviter le réalisme photographique (PBR strict) afin que le monde 3D ressemble à un tableau vivant qui accueille parfaitement vos illustrations 2D.

## 2. Caméra et Sprites (Le "Billboarding")
- **Caméra Libre :** Le joueur/la joueuse peut faire pivoter et incliner la caméra en 3D autour de l'arène pour observer le terrain.
- **Billboarding 2D :** Les sprites 2D des personnages pivotent automatiquement sur leur axe Y pour toujours faire face à l'écran. Cela crée un effet de "découpages en papier" (Papercut) dynamique et très stylisé, similaire à *Don't Starve* ou *Paper Mario*.

## 3. Topologie de l'Arène (Les Piliers Hexagonaux)
- **Îlots Flottants :** La grille tactique n'est pas un sol plat continu. Elle est composée de **piliers hexagonaux physiques**, modélisés individuellement.
- **Verticalité et Vide :** Ces hexagones forment des îles flottant dans les cieux. Le bas des piliers se fond progressivement dans les ténèbres ou la brume (Effet "Abyssal Fade" du shader), renforçant l'impression d'une arène suspendue hors du temps (façon *Final Fantasy Tactics*).

## 4. Atmosphère et Lumière (Éthéré et Divin)
L'ambiance lumineuse doit retranscrire la nature divine du jeu :
- **Atmosphère "Olympe" :** La lumière globale est douce, chaleureuse et céleste.
- **Couleurs :** Utilisation de palettes douces, parfois pastel (aubes dorées, crépuscules violacés). Les ombres ne sont pas d'un noir oppressant mais colorées.
- **VFX & Magie :** Utilisation de brume (fog) et de lueurs douces. La magie s'exprime par des éléments organiques (fissures divines, runes) plutôt que par des explosions visuellement surchargées. (Références : *Journey*, *Genshin Impact*).

---
*Ce document sert de référence (Bible Visuelle) pour la création de tous les futurs shaders, modèles 3D et effets visuels.*
