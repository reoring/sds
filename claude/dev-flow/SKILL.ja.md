# dev-flow — 段階開発フロー

[English](SKILL.md) | **日本語**(参考訳 — 正本は英語版)

> 段階開発フローの規律 — 構想 → read-only scout → 設計 → PoC → 確証 → 実装 →
> 手動 Live 反映 → 観察 → 確定。非自明な feature/設計/issue 作業の開始時、
> 「いま何工程?」の確認、前進前の gate チェック、live/本番を変更する前に使う。
> 案件ごとの状態ファイル、fail-closed な gate、receipt 雛形を提供する。

## 原則(一行)

**現実との接触を、いちばん安い工程へ前倒しする。** 高価な工程(live mutation・
長時間パイプライン・承認の消費)は確認の場であって発見の場ではない。各工程は
前段の receipt を入力にとるため、設計が「頭の中の環境像」に閉じることを防ぐ。

このフローは実際の失敗パターンから蒸留した: 想像上の環境に対して書かれた設計が
最初の ground truth 接触で崩壊した。1時間級のリリースパイプラインがデバッグ
ループとして繰り返し焼かれた。安いローカル chain テストで捕まえられた欠陥に、
本番の one-shot 試行が消費された。

## 8工程

| # | 工程 | 成果物(receipt) | 前進 gate |
|---|---|---|---|
| 0 | 構想メモ | what/why/成功条件を1枚(設計ではない — scout の scope 指定) | — |
| 1 | 調査(scout) | 実行コマンド付きの read-only 環境実測。欠測は正直に記録 | receipt 封緘済み。設計が参照する事実すべてに裏付け |
| 2 | 設計 | scout 事実に bind した設計 doc + 独立レビュー verdict | Blocking 0。scout の欠測が blocking として明示 |
| 3 | PoC | 使い捨て spike の receipt: 証明したこと**と証明していないこと** | 初物要素すべてに disposition |
| 4 | 確証 | full-chain preflight ログ + 封印 packet | 実行 chain 全段が隔離環境で green — 「live で初めて試される要素ゼロ」を証明 |
| 5 | 実装 | merged PR(テスト・CI・レビュー) | CI green + approve + 設計整合 |
| 6 | 手動 Live 反映 | 耐久実行 terminal(記録先行) | 工程4 packet が有効、封印以降 chain 無変更 |
| 7 | 観察 | readback + soak receipt(実測値、未観測領域) | readback 一致、soak 完走 |
| 8 | 確定 | 封緘 evidence、issue close、教訓の還流 | — |

工程ごとの絶対規則:

- **scout は read-only 厳守。**「`<command>` で実測した」と書く。「〜のはず」禁止。
  403 / 到達不能は「未観測 = 後段 blocking」と記録し、推測で埋めない
- **PoC 成果物は使い捨て。** PoC のコードや fixture を live に転用しない
- **Live 反映は手動・one-shot・記録先行**: write-ahead attempt receipt → 1回実行 →
  耐久 terminal。自動 retry・自動 rollback 禁止
- **観測手段は工程2で設計に含める。** live 後の観測の後付けは運用課題ではなく設計欠陥

## 状態ファイル

案件ごとに `flow/<topic>-flow.md` を1本(作業ディレクトリ配下)。フロー位置の SOT。

```markdown
# flow: <topic>
- started: <date> / owner: <lane or person>
- current stage: <N>. <name>

| stage | status | receipt (path + SHA) | notes |
|---|---|---|---|
(0〜8 の行)

## Rollback history
- <date> stage N -> M: <理由1行>
```

前進/差し戻しのたびに必ず更新。receipt 列は**パス + SHA**。「口頭で done」は done ではない。

## 差し戻し早見表

| ズレの発見場所 | 戻る先 |
|---|---|
| 設計レビューで scout にない前提 | 1(scout 引き直し or 設計修正)|
| PoC で設計仮説が崩れた | 2 |
| 確証で未検証の chain 段 | 3 |
| 実装が設計前提から逸脱 | 2(設計改版 — その場のつじつま合わせ禁止)|
| Live 反映失敗(耐久 terminal 残存) | 4(packet 再発行・方式再点検)|
| 観察で問題発見 | 裁定(2, 5, 6 のいずれか)— 自動 rollback 禁止 |

**gate を満たさないのに進みたくなったら**: gate が間違っているのではなく、
上流のどこかがズレている。差し戻し先を探すこと。

## 担い手とモデル(worker fleet 使用時)

- 実装系工程(3–5, 7)は **fleet 標準ギア**の worker に(例: Codex fleet は
  `gpt-5.6-terra` medium、Claude Code fleet は **`sonnet`**)
- 上位ギア(Codex `sol` effort low / Claude Code `opus`)は「はまり突破」と
  blocking スポットレビュー専用で**台帳制** — 常駐禁止
- 工程6(live)は**人間 gate**: オーナー本人または明示授権された executor。モデルではない
- lane の生成・寿命は issue-lane skill(1 issue = 1 lane)に従う

## 停止条件(circuit breaker)

進捗は成果(実 mutation・readback・残工程)で数える — receipt や successor
チケットの数ではない。同一 operation の 2 rejection / 30分停滞 / protocol defect
3連続 のいずれかで停止し、次の試行を禁止して方式を再設計する。fail-closed は
壊れた方式を無限に回す許可ではない。

## プロジェクト適応

プロジェクトに正本のフロー文書があればそちらが優先。本スキルは正本を持たない
プロジェクトの既定値。導入時は工程表をプロジェクトの正本 doc にコピーし、
プロジェクト固有の gate・担い手・パス規約をそこに蓄積していく。
