# dev-flow — 段階開発フロー(Codex 版)

[English](SKILL.md) | **日本語**(参考訳 — 正本は英語版)

> 段階開発フローの規律 — 構想 → read-only scout → 設計 → PoC → 確証 → 実装 →
> 手動 Live 反映 → 観察 → 確定。非自明な feature/設計/issue 作業の開始時、
> 自分の作業がどの工程かの確認、live 状態を変更する承認を求める前に使う。
> 工程ごとの receipt と fail-closed な gate を強制する。

## 原則

**現実との接触を、いちばん安い工程へ前倒しする。** 高価な工程(live mutation・
長時間パイプライン・承認の消費)は確認の場であって発見の場ではない。各工程は
前段の receipt を入力にとるため、設計が想像上の環境に閉じることはできない。

## 8工程

| # | 工程 | 成果物(receipt) | 前進 gate |
|---|---|---|---|
| 0 | 構想メモ | what/why/成功条件 1枚(設計ではない) | — |
| 1 | scout | 実行コマンド付き read-only 実測。欠測は正直に | receipt 封緘済み。設計関連の事実すべてに裏付け |
| 2 | 設計 | scout 事実に bind した設計 doc + 独立レビュー | Blocking 0。scout 欠測が blocking 明示 |
| 3 | PoC | 使い捨て spike receipt: 証明したこと**と証明していないこと** | 初物要素すべてに disposition |
| 4 | 確証 | full-chain preflight ログ、封印 packet | chain 全段が隔離環境で green — 「live で初物ゼロ」を証明 |
| 5 | 実装 | merged PR(テスト・CI・レビュー) | CI green + approve + 設計整合 |
| 6 | 手動 Live 反映 | 耐久実行 terminal | packet 有効、工程4以降 chain 無変更 |
| 7 | 観察 | readback + soak receipt | readback 一致、soak 完走 |
| 8 | 確定 | 封緘 evidence、issue close、教訓還流 | — |

## worker lane のルール

- **自分の工程を知る。** task prompt にどの工程かが書かれているはず。上流の
  receipt(scout receipt・設計 verdict・PoC receipt・packet)が無ければ停止して
  報告 — 記憶から再構成しない
- **scout は read-only 厳守。** 調査コマンドのみ(`gh api` GET、
  `aws describe|list|get`、`kubectl get`、source 読み)。事実は
  「`<command>` で実測」と書く。「〜のはず」禁止。403/到達不能は
  「未観測 = 後段 blocking」と記録し、推測で埋めない
- **PoC 成果物は使い捨て。** PoC のコードや fixture を live に転用しない
- **工程6は人間 gate。** live mutation は手動・one-shot・記録先行(write-ahead
  receipt → 実行 → 耐久 terminal)。自動 retry・自動 rollback 禁止。封印済み
  工程4 packet なしに live 変更を求められたら、拒否して報告する
- **park の前に receipt を出す。** パス + SHA。receipt の無い作業は存在しない

## 担い手とモデル(worker fleet 使用時)

- 実装系工程(3–5, 7)は fleet 標準ギアの worker に — Codex lane:
  `gpt-5.6-terra` medium、Claude Code lane: **`sonnet`** が既定実装者
- 上位ギア(Codex `sol` effort low / Claude Code `opus`)は台帳制のブースト /
  スポットレビューのみ — 常駐禁止
- 工程6(live)は人間 gate: オーナーまたは明示授権 executor。モデルではない

## 停止条件(circuit breaker)

進捗は成果(実 mutation・readback・残工程)で数える — receipt や successor の
数ではない。同一 operation の 2 rejection / 30分停滞 / protocol defect 3連続で、
successor の生成を止めて方式を再設計する。fail-closed は壊れた方式を回し続ける
許可ではない。

## プロジェクト正本の優先

repo/vault に正本の dev-flow 文書があればそちらが優先。本スキルは正本を持たない
プロジェクトの既定値。新プロジェクトでは工程表を正本 doc にコピーし、固有の
gate・担い手・パスをそこに足していく。
