# issue-lane — 「1 issue = 1 lane」のライフサイクル規律

[English](SKILL.md) | **日本語**(参考訳 — 実行時に読み込まれる正本は英語版)

> herdr で管理するエージェント fleet に「1 issue = 1 lane」を徹底させる。
> issue を worker lane に割り当てるとき、issue が閉じたとき(「lane も畳んで」)、
> lane の棚卸し(「lane 監査」)のときに使う。lane を作るときは tab と pane の
> **両方**に issue ID を刻み、issue が閉じたら lane も畳む。tab ラベル ×
> pane ラベル × tracker の状態を三点照合して、ズレ(drift)を検出する監査つき。

lane の作成・撤収・モデルの昇格降格には、fleet ごとの正式手順(bootstrap /
teardown / model-gear の規約)がそれぞれある。このスキルの担当は、それらを
**issue の一生に縛りつけること**と、**ズレの検出**だ。

## なぜ必要か

複数の PO がエージェント fleet を運用する現場で、実際にこうなった:
ブースト昇格した lane が高価なモデルのまま別の issue に使い回され、コストが漏れた。
閉じた issue の lane が残り続け、fleet の一覧が実態を映さなくなった。pane の
ラベルだけ付け替えて lane がこっそり issue をまたいで再利用され、古い真実は
tab のラベルにしか残っていなかった。

lane を issue と1対1に縛れば、`pane list` がそのまま「いま何が進んでいるか」の
一覧になる。管理が、申告ではなく実測に戻る。

## 破ってはいけない4カ条

1. **1 issue = 1 lane = 書き手は1本。** issue ID は**二層とも**に刻む:
   - **tab ラベル**: 先頭が `<ISSUE-ID>`(例 `PROJ-123 api-freeze`)
   - **pane(エージェント)ラベル**: `<space>/<ISSUE-ID>[-役割]`(例 `api/PROJ-123`)

   二層の指す issue が食い違っていたら、それは**使い回しのズレ**(pane ラベルだけ
   付け替えて別の作業をしている状態)。PO の常駐 pane(tab ラベル `po`)だけは
   この規則の対象外
2. **lane の寿命は issue と同じ。** 割り当てと同時に生まれ、Done/Canceled に
   なったら畳む。「次の issue にそのまま使う」は禁止 — 次の issue には新しい lane を
   立てる(モデルも履歴も worktree もまっさらから)
3. **モデルは fleet の標準を使う。** lane は Codex でも Claude Code でもよい。
   標準の実装担当は Codex なら `gpt-5.6-terra`(medium。ブースト用の `sol` は
   effort low が基本)、Claude Code なら **`sonnet`**(ブースト層は `opus` など)。
   上位モデルで走ってよいのは、モデル台帳に有効な記載がある間だけ。台帳にない
   上位モデルは見つけ次第、標準へ降格する
4. **lane の管理ファイルを作らない。** 正本は、生きている `herdr pane list` と
   issue tracker の突き合わせ。一覧ファイルを作れば、それは実態とズレていく
   第二の正本になる

## 割り当て(issue → lane)

1. **二重割り当ての確認**: 対象 workspace の `herdr pane list` に同じ issue ID の
   pane がすでにあれば、新しく作らずそこへ連絡する
2. **新設**は fleet の bootstrap 手順で。lane ごとにランタイム(Codex か
   Claude Code か)を選び、モデルを**明示**する — 既定値に頼らない(Codex:
   `gpt-5.6-terra`、Claude Code: `sonnet`)。tab ラベルは issue ID で始める
3. **着手指示**(pane ID 宛)には、必ずこの一文を入れる:

   > この lane は <ISSUE-ID> 専任。完了したらバックグラウンドのプロセスをすべて
   > 止めてから、待機して報告すること。ほかの issue には手を出さない。
   > test を弱める・skeleton 実装で green を満たすのは手順違反 — あなたが
   > 見ていない held-out test で検出され、やり直しになる。test には diff を
   > 当てないこと。

## 撤収(issue クローズ → lane を畳む)

きっかけは、PR のマージと issue の Done/Canceled を **tracker で実測したとき**。
lane 自身の「終わりました」では動かさない。tracker は何でもいい: Linear
(MCP の `get_issue`)、Jira(CLI / MCP。`PROJ-123` 形式の key は Linear と同じ
`ABC-123` パターン)、GitHub Issues(`gh issue view`)。

1. tracker で issue の状態を確認する
2. 安全に撤収する: バックグラウンドのプロセスが残っていないか検証し(特に共有
   ロックを握るプロセス)、止めてよいか判定してから、worktree とブランチを消す
3. **pane は閉じる。** 名前を付け替えて再利用しない — それがラベルと issue の
   ズレの始まりになる
4. モデル台帳にブーストの記載が残っていれば、閉じる

## 監査(「lane 監査」)

**`pane list` だけを見て監査しない。** 実際にあった話: pane ラベルは今の issue を
指していて健全に見えたのに、tab ラベルは閉じた issue のままだった — 使い回しの
痕跡は tab の層にしか残っていなかった。

1. `herdr workspace list` を取り、workspace ごとに `herdr tab list` と
   `herdr pane list` の**両方**を取得して、`tab_id` で突き合わせる
2. tab ラベルと pane ラベルのそれぞれから issue ID を取り出し、(a) 二層どうし、
   (b) tracker の状態、の両方と照合する(三点照合)。`ABC-123` パターンは
   Linear と Jira で共通。GitHub Issues は `#<番号>` / `owner/repo#<番号>`
3. モデルは pane の画面フッターから実測する:
   ```bash
   herdr pane read <pane> --source visible --lines 3 --format text | tail -1
   ```
4. 違反の種類と対処:

| 違反 | 見つけ方 | 対処 |
|---|---|---|
| 迷子 lane | どちらの層にも issue ID がない | 持ち主の PO に確認。次の監査まで宙に浮いたままなら閉じる |
| ゾンビ lane | issue は Done/Canceled なのに pane が生きている | ただちに撤収 → close |
| 書き手の重複 | 同じ issue ID の pane が2本以上 | 後から立った方を止め、先発に集約 |
| 無断ブースト | フッターが上位モデルなのに台帳に記載がない | 降格する — Codex pane は `scripts/model-switch.sh`(fail-closed。番号の思い込み押し禁止)、Claude Code pane は `/model` ピッカーを同じ「画面を読んでから押す」流儀で。持ち主の PO に通知 |
| 使い回しのズレ | 二層が食い違う、または tab が閉じた issue を指したまま | 実際に何をやっているかを特定。作業中なら待機を待って撤収。次の issue には新しい lane |
| 割り当て漏れ | In Progress の issue に対応する lane がない | 持ち主の PO に報告(勝手に lane を立てない — 割り当ては PO の裁量)|

5. 報告は最後にまとめて1回: workspace / pane / issue / 違反 / 対処。
   違反ゼロなら「N pane を確認、違反 0」と件数つきで言う

## やらないことリスト

- lane の管理ファイルは作らない(生きた実測 + tracker が正本)
- 閉じた issue の lane を「また使うかもしれないから」で残さない
- 無断ブーストの降格を後回しにしない — 見つけたそのターンで終わらせる
- 持ち主 PO の割り当て判断を代行しない(監査がやるのは検出と機械的な対処だけ)
