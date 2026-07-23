# sds — Software Development Skills

[English](README.md) | **日本語**

複数の AI エージェントを束ねて、ソフトウェア開発を規律よく進めるためのスキル集。
Claude Code でも Codex でも使える。

実際に本番開発で毎日回しているワークフロー — PO(スーパーバイザー)セッションが
計画を立て、tracker に issue を起票し、実装は worker lane に任せる — を、
どのプロジェクトでも使える形に汎用化したもの:

> **dev-flow** で計画を立て、**issue-lane** で issue ごとに lane を1本立てて任せ、
> **herdr-event-watch** でイベント駆動に見守る。

## なぜ作ったか — 課題と解決

**課題その1: 何もかも最上位モデルにやらせると、コストがもたない。**

計画も実装もレビューも1つの強力なセッションで済ませると、トークンの大半を占める
「もう仕様が固まっている実装作業」にまで最上位モデルの単価を払うことになる。
しかも仕組みで縛らない限り、強いモデルは安いモデルで十分な仕事にも居座り続ける。
これは想像の話ではなく、本番運用で実際に観測した — ブースト昇格した lane が
高価なモデルのまま、まったく別の issue に使い回されていた。

**課題その2: AI まわりのツール、増えすぎ。**

毎週のように新しいオーケストレーション基盤が出てきて、導入して、学んで、依存する
ことになる。でも、エージェント fleet の監督にそういう新ツールは要らない。
エージェントにループとゴールさえ与えれば、手元にあるシンプルな道具の組み合わせ —
pane を並べるマルチプレクサ、いつもの issue tracker、`gh`、用途を1つに絞った
小さなシェルスクリプト — で同じことが実現できる。この repo は意図的に
UNIX 哲学で作ってある: **新しい基盤なし、ランタイム依存なし**。あるのは
markdown のスキルファイルと、すでに使っている道具をつなぐ小さなスクリプトだけだ。

**解決: いま持っている道具だけで、「判断する仕事」と「手を動かす仕事」を分ける。**

| 役割 | モデル | トークン消費 | 仕事の中身 |
|---|---|---|---|
| PO(プロジェクトに1人) | 最上位(Opus 4.8 / Fable 5) | 少ない | 計画、gate の設計、issue 起票、receipt の検証、裁定 |
| worker(issue ごとに1本) | 標準(`sonnet` / `gpt-5.6-terra` medium) | 大半 | 仕様が固まった issue の実装、receipt の提出 |
| ブースト / スポットレビュー | 最上位・**一時的** | 例外時のみ | 行き詰まりの突破、重要局面のレビュー — 台帳で管理 |

判断が要る場面は、トークン全体から見ればごく一部にすぎない。だから最上位モデルには
「結果を左右する判断」のときだけ働いてもらい、物量の大半を占める実装は標準モデルで
回す。さらに、ブースト昇格には台帳への記載を必ず義務づけ、lane は issue が閉じたら
必ず畳む(issue-lane)。これで「高いモデルの居座り」は、気をつける話ではなく
**そもそも起こせない構造**になる。判断は最上位品質、物量は標準価格 — これが
このスキル集の芯にある考え方だ。

## スキル

| スキル | 何を守らせるか |
|---|---|
| [dev-flow](claude/dev-flow/SKILL.ja.md) | 開発を8つの工程(構想 → 事前調査 scout → 設計 → PoC → 確証 → 実装 → 手動での本番反映 → 観察 → 確定)に分け、工程ごとに証拠(receipt)と通過条件(gate)を義務づける。差し戻し先の早見表と、暴走を止める停止条件つき |
| [issue-lane](claude/issue-lane/SKILL.ja.md) | 「1 issue = 1 lane」の徹底。tab と pane の両方に issue ID を刻み、issue が閉じたら lane も畳む。モデルのブーストは台帳管理。tab × pane × tracker の三点照合でズレ(drift)を検出する監査つき |
| [herdr-event-watch](claude/herdr-event-watch/SKILL.ja.md) | fleet の監視を定期巡回からイベント駆動へ。確実に残る成果物ファイル(inbox)を主信号に、lane の done/blocked 遷移と PR チェックの確定だけを通知させる |
| [po-handover](claude/po-handover/SKILL.ja.md) / [po-resume](claude/po-resume/SKILL.ja.md) | PO session の世代交代(Claude Code 専用 — このトポロジでは PO は Claude Code で動く)。context 50〜60% で交代する: 引き継ぎは「地図」(進行中の差分 + 正本ポインタだけ)、新 session はすべて live で測り直し、監視を再武装し、道具箱を意識に載せてから業務に入る |
| [main-po-patrol](claude/main-po-patrol/SKILL.ja.md) / [watch-po](claude/watch-po/SKILL.ja.md) | 複数プロジェクトを並走させるときの第3層: **main PO**(PO たちの PO)が各プロジェクト PO の健全性 — context 使用率・劣化・強制モデル切り替わり — を見回って世代交代を駆動する。watch-po はその常設センサー(承認プロンプト停止・context 閾値・モデル切替・pane 消滅)。Claude Code 専用 |

worker lane には **Codex と Claude Code のどちらも使える**。標準の実装担当は
Codex なら `gpt-5.6-terra`(medium)、Claude Code なら `sonnet`。上位モデル
(Codex の `sol`、Claude Code の `opus`)は台帳管理の一時ブースト専用。

## issue 管理は Linear でも Jira でもいい

issue のライフサイクルは、いま使っている tracker の上でそのまま回せる。
**Linear でも Jira でも**そのまま動く(GitHub Issues も可):

- issue の起票・更新は PO が tracker 上で行う(Linear は MCP、Jira は CLI か MCP、
  GitHub は `gh` コマンド)
- lane のラベルには tracker の issue key を刻む。Linear と Jira はどちらも
  `ABC-123` 形式なので、ラベルの規約も監査の抽出ロジックもそのまま共通で使える
- lane を畳むきっかけは **tracker で実測した Done/Canceled** だけ。lane 自身の
  「終わりました」報告では動かさない

## ワークフロー全体像

3つのスキルは、次の1本のデリバリーループとして噛み合う(この repo の元になった
実際の流れ — ある MVP を計画から本番稼動まで持っていったときのもの):

1. **場を作る。** PO 用の `<project>` space(Claude Code、Opus 4.8 / Fable 5、
   tab 名 `po`)と、worker 用の `<project>-impl` space を herdr に立てる
2. **計画する — dev-flow 工程 0〜2。** PO が構想メモを書き、読み取り専用の
   scout lane に環境の実態調査をさせ、その実測結果に基づいて設計し、独立レビューに
   かける。実態を見ないままの設計はここで禁止される
3. **issue に割る。** レビューを通った設計を、PO が tracker の issue に分解する
   (Linear / Jira)。1つの issue は lane 1本分の大きさにし、受け入れ条件と
   「何を receipt として提出するか」を明記して、依存関係を張る
4. **lane に任せる — issue-lane。** 依存が解けた issue から順に、`<project>-impl`
   に lane を1本ずつ立てる(tab 名 = issue key、pane 名 = `<project>/<KEY>`、
   モデルは `sonnet` / `terra` medium)。着手指示には「この lane はこの issue 専任」
   の一文を必ず入れる
5. **見守る — herdr-event-watch。** lane・receipt inbox・PR チェックを watcher
   1本で監視する。PO は巡回せず、イベントに反応する: INBOX が来たら receipt の
   実物を検証、CI が通ったら merge を判定、blocked を見たら介入。行き詰まった
   lane は台帳に記載してブーストし、突破したら元に戻す
6. **ループを閉じる。** tracker が Done になったら lane を畳む(issue-lane)。
   レビューで見つかった課題は follow-up issue として起票する
7. **本番に出す — dev-flow 工程 4〜8。** 実行手順の全段を隔離環境で検証しきって
   から、人間の承認を経て手動で本番反映。反映後は実測(readback)と経過観察を経て、
   確定を宣言し、得られた教訓をフロー文書に書き戻す

PO は実装せず、worker は本番に触らない。受け渡しはすべて receipt で、状態の変化は
すべて実測する。高いモデルが出てくるのは、判断が発生する場面だけだ。

## herdr の構成(fleet トポロジ)

スキル群は、プロジェクトごとに次の herdr workspace 構成を前提にしている:

```
herdr
├── <project>              PO 用 space
│   └── tab "po"           プロジェクトの PO セッション — Claude Code の
│                          Opus 4.8 または Fable 5 を推奨
└── <project>-impl         worker 用 space(1 issue = 1 tab = 1 lane)
    ├── tab "PROJ-123 api-freeze"   pane "<project>/PROJ-123"        実装担当
    ├── tab "PROJ-124 rate-limit"   pane "<project>/PROJ-124"        実装担当
    └── tab "PROJ-124-review"       pane "<project>/PROJ-124-review" レビュー担当(読み取り専用)
```

- **PO はプロジェクトに1人。** dev-flow で計画し、tracker に issue を起票し、
  issue-lane で lane を割り当て、herdr-event-watch で見守る。プロジェクト自身の
  space の `po` という tab に常駐し(この tab だけ issue-ID ラベル規則の対象外)、
  自分では実装しない — 任せる・検証する・裁くに徹する。PO の session も
  使い捨てでいい: context 50〜60% になったら **po-handover → po-resume** で
  世代交代し、判断が鈍る前に入れ替える
- **worker は `<project>-impl` space に集める。** issue 1つにつき tab 1つ。
  tab 名は issue ID で始め、pane 名は `<project>/<ISSUE-ID>[-役割]` とする。
  この「二層ラベル」が、lane の使い回しによるズレを検出可能にする。lane は
  割り当てと同時に生まれ、issue が閉じたら畳まれる
- **実装担当**は標準モデル(Claude Code `sonnet` か Codex `gpt-5.6-terra` medium)。
  issue ごとに読み取り専用のレビュー lane(`-review` サフィックス)を任意で
  付けられる。ブーストは台帳管理・一時限定
- この構成のねらいは1つ: **`pane list` を見れば「いま何が進んでいるか」がそのまま
  わかる**状態を保つこと
- **プロジェクトを何本も並走させるなら**、第3層を足す: **main PO** session
  (これも Claude Code・最上位モデル)が、各プロジェクトの PO そのものを見守る —
  main-po-patrol で健全性を見回り、watch-po を常設センサーに、世代交代を駆動する。
  対象はあくまで PO で、lane には触れない

## Claude Code 用と Codex 用

同じスキルを、それぞれのランタイムに合わせた2つの版で収録している:

- `claude/` — Claude Code 用(`~/.claude/skills/` に配置)。常駐監視には Monitor
  ツールを、tracker には MCP / CLI を使う
- `codex/` — Codex CLI 用(`~/.codex/skills/` に配置)。worker lane 自身が守るべき
  自己規律の章が加わり、Monitor の代わりにバックグラウンドターミナルを使う

同梱スクリプト(いずれも本番で鍛えたもの・fail-closed 設計):

- `herdr-event-watch/scripts/herdr-event-watch.sh` — イベントの発信器
  (INBOX / LANE / CI / WATCH ERROR の行を出力する)
- `issue-lane/scripts/model-switch.sh` — codex TUI pane のモデルを安全に切り替える。
  実際のピッカー画面を読み、モデル名の完全一致から選択番号を割り出し、切り替え後に
  画面のフッターで検証する。「番号の思い込み押し」で旧世代モデルに誤切替した実事故を
  二度と起こさないために生まれた

## インストール

```bash
# Claude Code
cp -r claude/* ~/.claude/skills/

# Codex CLI
cp -r codex/* ~/.codex/skills/
```

スキルは自己完結している。スクリプトを使う環境には `herdr`(pane fleet の CLI)、
`gh`、`jq`、`python3` が PATH にあること。

## 設計思想

- **「やりました」ではなく証拠を。** 工程や lane の操作は、必ず残るファイル
  (パス + SHA)を証拠として生む。口頭の「done」は done ではない
- **迷ったら止まる(fail-closed)。** メニューに目的のものがない、receipt がない、
  検証が一致しない、pane に届かない — どの場合も中断して報告する。推測で進めない。
  検証していない成功を主張しない
- **正本は実測。** ズレていく管理ファイルは作らない。監査は、生きている pane/tab の
  状態と tracker を突き合わせて行う
- **イベントが主、巡回は保険。** 消えないファイルは見逃さない。サンプリングされる
  状態は見逃す — 設計はその両方を前提に組む

## 実運用の実績

このスキル集は机上の空論ではない。**AppThrust**
([appthrust.com](https://appthrust.com/) ·
[github.com/appthrust](https://github.com/appthrust/))の開発で実際に使っている
ワークフローそのもので、計画・実装・レビュー・本番リリースまでをマルチエージェント
fleet で毎日回している。

効果も実測済みだ。この PO/worker 分離と台帳管理のブースト運用に切り替えたことで、
トークン費用は**1日あたり約 $12,000 から約 $900 へ — およそ 92% の削減**。
判断が要る場面の品質は最上位モデルのまま。

## ライセンス

MIT
