extends Node

## グローバルな enum とゲーム全体で参照する型定義。
## 可変状態は持たない（可変状態は RunState のみ）。

enum Faction { PLAYER, ENEMY, HOSTAGE }
enum Stage { STAGE_1, STAGE_2, STAGE_3, STAGE_4, STAGE_5 }
## 得点の計算で使う武器種。`PlayerWeapon.WeaponKind` と同じ並びだが、
## autoload からプレイヤー側のクラスへ依存しないようここにも置く。
enum ScoreWeapon { UNARMED, GUN, KATANA }
