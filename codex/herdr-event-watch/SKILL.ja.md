# herdr-event-watch — event-driven な lane/PR 監視(Codex 版)

[English](SKILL.md) | **日本語**(参考訳 — 正本は英語版)

> herdr lane・耐久 inbox artifact・PR required check を、固定間隔ポーリングの
> 代わりに event-driven で監視する。worker lane の監督(「X が終わったら教えて」)、
> merge 判定前の PR check 待ち、定期巡回が「変化なし」ばかりのときに使う。
> `scripts/herdr-event-watch.sh` を background terminal で走らせ、emit される
> イベント行に反応する。

スケジュールでポーリングする代わりに、何かが変わった瞬間に通知を受ける。
固定間隔巡回は二重に損: 開始3分で park した lane に最大インターバル分気づかず、
何も起きていなくてもターンを焼く。

## 使い方(Codex ランタイム: background terminal)

Codex には持続 Monitor ツールが無い — watcher を **background terminal** で
走らせ、フォアグラウンドに戻ったときに出力を確認する:

```bash
# 起動(background terminal で)
bash <skill-dir>/scripts/herdr-event-watch.sh \
  --workspace <wsId> --prefix <laneLabelPrefix> \
  --inbox <receiptDir> --inbox-prefix <filePrefix> \
  --repo <owner/repo> --check <requiredCheckName> --pr <n> [--pr <n> ...] \
  | tee /tmp/herdr-events.$$.log
```

- stdout 1行 = 1イベント。`tee` で耐久ログを残し、作業中のイベントを失わない
- background terminal 無しの単発確認は `--once`
- **park する前に** background terminal を `/stop` で止める — 漏れた watcher
  プロセスはターンを越えて生き残る

## 引数

| 引数 | 必須 | 意味 |
|---|---|---|
| `--workspace` | ✔ | herdr workspace ID(`herdr workspace list`)|
| `--prefix` | | lane ラベル前方一致フィルタ(既定: 全 labeled pane)|
| `--inbox`(複数可) | | **耐久 artifact 到着監視(primary)** — receipt/verdict の落ちる dir |
| `--inbox-prefix` | | ファイル名前方一致フィルタ |
| `--repo` / `--pr`(複数可) | | PR required check 監視 |
| `--check` | | required check 名(既定 `cloud`)|
| `--interval` | | poll 秒(既定 10。gh は約1回/分に間引き)|
| `--once` | | 1周で exit |

## イベント

- `INBOX <filename>` — 耐久 artifact 到着。取りこぼし無し(primary)。
  既存ファイルは無音の基準線 — watcher (再)起動後は古い到着分を手動 sweep
  (`ls -t`)
- `LANE <label>=done|blocked` — サンプリングされた遷移。transient は落ちうる。
  stall/blocked 検出の backstop
- `CI PR#<n> <check> -> pass|fail (head <sha>)` — PR×結果×head ごとに1回
- `WATCH ERROR <msg>` — 監視自体の継続的失敗

## 設計ルール

1. working⇄idle の揺れは流さない — done/blocked のみ
2. CI は pass も fail も emit(silence ≠ success)
3. gh/herdr の一時エラーでループを殺さない。継続失敗のみ WATCH ERROR
4. watcher 死亡に備えて粗い時間ベース巡回を backstop に残す

## 罠(実測済み)

- ラベル無し pane は監視に映らない — lane 作成時に必ずラベル
  (issue-lane の二層規則)
- 1 watcher に PR を積みすぎると gh rate limit — 判定待ちの PR だけに絞る
- **`done` は transient**: worker の done は poll の隙間に消費されうる。
  耐久 inbox artifact を primary の信号にし、worker には「receipt を書いて
  **から** park」を守らせる
- 通知は「見ろ」であって「信じろ」ではない — 行動する前に pane/receipt を
  自分で読む
