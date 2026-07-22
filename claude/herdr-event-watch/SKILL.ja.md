# herdr-event-watch — event-driven な lane/PR 監視

[English](SKILL.md) | **日本語**(参考訳 — 正本は英語版)

> herdr fleet の監督を固定間隔巡回から event-driven に切り替える。lane の
> done/blocked 遷移、PR required check の pass/fail 確定、耐久 inbox artifact の
> 到着だけを Monitor ツール経由で通知させる。「event driven で監視」「lane/PR が
> 終わったら教えて」、定期巡回が「変化なし」報告ばかりになったときに使う。

**何かが変わった瞬間**に通知を受けるための正本手順。固定間隔巡回は二重に損する:
開始3分で park した lane に最大インターバル分気づかず、何も起きていなくても回る。

## いつ使うか

- worker/review lane を複数走らせていて、PARK(done)/ blocked を即座に拾いたい
- merge 判定の前に PR required check(branch protection)の green/fail を待ちたい
- 定期の「worker 巡回」cron が「変化なし」報告に形骸化してきた

## 使い方

Monitor を **persistent: true** で1本 arm する(lane と CI を同じ watcher で見る):

```
Monitor({
  description: "<何を見ているか — 例: api lanes + inbox + PR #109 CI>",
  persistent: true,
  command: "bash <skill-dir>/scripts/herdr-event-watch.sh \
    --workspace <wsId> --prefix <laneLabelPrefix> \
    --inbox <receiptDir> --inbox-prefix <filePrefix> \
    --repo <owner/repo> --check <requiredCheckName> --pr <n> [--pr <n> ...]"
})
```

引数:

| 引数 | 必須 | 意味 |
|---|---|---|
| `--workspace` | ✔ | herdr workspace ID(`herdr workspace list`)|
| `--prefix` | | lane ラベルの前方一致フィルタ(例 `api/`)。省略時は全 labeled pane |
| `--inbox`(複数可) | | **耐久 artifact 到着監視(primary)** — receipt/verdict が落ちる dir |
| `--inbox-prefix` | | ファイル名の前方一致フィルタ |
| `--repo` / `--pr`(複数可) | | PR required check 監視。省略時は lane のみ |
| `--check` | | required check 名(既定 `cloud`)|
| `--interval` | | poll 秒(既定 10。gh は約60秒に1回に自動間引き)|
| `--once` | | 1周だけ回して exit(動作確認用)|

## イベント(stdout 1行 = 1通知)

- `INBOX <filename>` — 新ファイル到着。**耐久 artifact なので取りこぼし無し
  (primary)。** watch 開始時の既存ファイルは基準線(無音)— 再 arm 後は
  停止中の到着分を手動 sweep する
- `LANE <label>=done|blocked` — lane がその状態に遷移した瞬間。サンプリングなので
  transient は落ちうる(罠参照)— stall/blocked 検出の backstop として使う
- `CI PR#<n> <check> -> pass|fail (head <sha>)` — required check の終端確定。
  PR×結果×head ごとに1回(head を dedup キーに含むので、update-branch 後の
  新 head での再確定も emit される)
- `WATCH ERROR <msg>` — 監視自体の継続的失敗

## 設計ルール(変更前に読む)

1. **working⇄idle の揺れは流さない。** done/blocked のみ — ノイズは event-driven
   監督を殺す
2. **CI は pass も fail も emit**(silence ≠ success)。fail を出せない監視は片目
3. **一時失敗でループを殺さない。** gh/herdr の単発エラーは握りつぶし、
   継続失敗のみ WATCH ERROR
4. **時間ベース巡回を backstop として残す。** イベントが primary、cron は
   watcher 死亡時の保険。cron 側は「状態確認 → 変化なければ即終了」で二重処理回避

## 運用

- **PR リスト変更時**(merge 完了・新 PR): Monitor task を止めて新引数で再 arm —
  Monitor の引数は動的に変えられない
- **停止**: TaskList で task ID を確認して TaskStop
- イベント受信後: artifact/pane を実物検証 → tracker 更新 → successor 起床。
  **通知は「見ろ」であって「信じろ」ではない** — 必ず自分で pane/receipt を読む

## 罠(すべて本番実測)

- `herdr pane list` は agent 未起動 pane のラベルを返さないことがある →
  ラベル無し pane は監視に映らない。lane 作成時に必ずラベルを付ける
  (issue-lane の二層ラベル規則)
- 1 watcher に大量の PR を積むと gh rate limit に当たる。「いま判定待ちの PR」
  だけに絞る
- Monitor スクリプト内の `sleep` は可。フォアグラウンドの裸 `sleep` 連鎖は
  harness にブロックされがち
- **`done` は transient — poll の隙間に消える**(2件実測)。worker の done は
  queued メッセージの消費で poll 間に消えうる。状態サンプリングは原理的に
  取りこぼす。対策は組み込み済み: `--inbox` で耐久 artifact(terminal receipt /
  verdict)を primary にする — ファイルは消えない。LANE watch は backstop に
  留め、worker には「receipt を inbox に書いてから park」の順序を守らせる
- **再 arm の隙間**: 再起動時に inbox 基準線を引き直すため、停止中の到着分は
  emit されない。再 arm 直後に必ず手動 sweep(`ls -t`)
