/* =========================================================
   ADHT プロトタイプ — ロジック
   AI 提案はモック（テンプレートからランダム生成）。
   データは localStorage に保存（仕様どおりローカルのみ）。
   ========================================================= */

(() => {
  "use strict";

  // セマンティック バージョニング 2.0.0 準拠。修正ごとに更新する。
  // 仕様書とバージョンを揃える（仕様書 v1.4 ⇔ アプリ v1.4.x）
  const APP_VERSION = "1.4.0";

  // エクスポートJSONの形式バージョン。
  // v2: progress（進捗度 0-100%）追加。v1（〜アプリv1.3.0）のインポートは可（progress=0で補完）。
  const EXPORT_FORMAT_VERSION = 2;

  const STORAGE_KEY = "adht-proto-v1";
  const PRIORITY = {
    gekiomo: { label: "🔥 激重", weight: 4, time: "まず5分だけ" },
    omoi:    { label: "重い",   weight: 3, time: "目安30分" },
    futsuu:  { label: "普通",   weight: 2, time: "目安15分" },
    karui:   { label: "軽い",   weight: 1, time: "目安5分" },
  };
  const BRAIN = {
    rightBrain: "🎨 右脳",
    leftBrain: "🧮 左脳",
  };

  /* ---------- 状態 ---------- */

  let state = load();

  function today(offset = 0) {
    const d = new Date();
    d.setDate(d.getDate() + offset);
    return d.toISOString().slice(0, 10);
  }

  function seedTasks() {
    return [
      mkTask("HDMIキャプチャの調査を行う", "leftBrain", "omoi", today(2)),
      mkTask("ブログのアイキャッチ画像を作る", "rightBrain", "futsuu", today(1)),
      mkTask("経費精算をやる", "leftBrain", "gekiomo", today(0)),
      mkTask("新アプリのアイデアをラフに描く", "rightBrain", "karui", today(4)),
    ].map((t) => ({ ...t, suggestions: generateSuggestions(t) }));
  }

  function mkTask(title, brainType, priority, deadline) {
    return {
      id: crypto.randomUUID(),
      title, brainType, priority, deadline,
      chat: [],          // AIとの会話 [{role: "user"|"ai", text, proposal?}]
      suggestions: [],
      firstStep: null,   // 決定した「最初の一歩」
      progress: 0,       // 進捗度 0/25/50/75/100 %（v1.4）
      createdAt: new Date().toISOString(),
    };
  }

  function load() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (raw) {
        const s = JSON.parse(raw);
        // 旧バージョンのデータを移行（context → chat、提案は3件に切り詰め）
        (s.tasks || []).forEach((t) => {
          if (!Array.isArray(t.chat)) {
            t.chat = t.context ? [{ role: "user", text: t.context }] : [];
            delete t.context;
          }
          t.suggestions = (t.suggestions || []).slice(0, 3);
          if (t.firstStep === undefined) t.firstStep = null;
          t.progress = normalizeProgress(t.progress); // v1.3以前のデータ移行
        });
        return s;
      }
    } catch (_) { /* 破損時はシードに戻す */ }
    return null;
  }

  function save() {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  }

  function initState() {
    state = {
      tasks: seedTasks(),
      settings: { tone: "gentle", briefingHour: "08:00" },
      filter: "all",
      consult: [], // AIに相談の会話履歴
    };
    save();
  }
  if (!state) initState();
  if (!Array.isArray(state.consult)) state.consult = []; // 旧データ移行

  /* ---------- モック AI ---------- */

  function pick(arr, n) {
    const pool = [...arr];
    const out = [];
    while (out.length < n && pool.length) {
      out.push(pool.splice(Math.floor(Math.random() * pool.length), 1)[0]);
    }
    return out;
  }

  function generateSuggestions(task) {
    const t = task.title.replace(/を?(行う|やる|する)$/, "");
    const generic = [
      `タイマーを5分だけセットして、「${t}」に関するメモを1行だけ書く`,
      `「${t}」でGoogle検索して、上から3件だけタイトルを眺める（読み込まない）`,
      `完璧は禁止。60点でOKと宣言してから、関連するアプリやタブを1つだけ開く`,
      `「${t}」をもっと小さく割るなら？と自問して、思いついた小タスクを1つメモする`,
      `終わったあとのご褒美を先に決める（コーヒー1杯など）。決めたら30秒だけ着手`,
      `誰かに「今から${t}やる」と宣言する（送らなくてもOK、下書きだけでも効く）`,
    ];
    const left = [
      `「${t}」のゴールを1文で書き出す（何ができたら完了？）`,
      `今日は情報集めだけの回にする。判断は明日の自分に任せる`,
      `メモアプリに比較表の枠だけ作る。中身は空でOK`,
      `所要時間を見積もって、カレンダーに15分だけブロックを置く`,
      `必要なもの（URL・書類・ツール）を1か所に集めるだけで今日は勝ち`,
    ];
    const right = [
      `参考になりそうな事例を3つだけ眺めて、良いと思った点を1語ずつメモ`,
      `下書き・ラフを「わざと雑に」1個作る。清書は別の日の自分がやる`,
      `頭に浮かんだキーワードを1分間ひたすら書き出す（質は問わない）`,
      `好きな曲を1曲かけて、曲が終わるまでだけ手を動かす`,
      `一番ワクワクする部分から着手する。順番は無視してOK`,
    ];
    const pool = generic.concat(task.brainType === "leftBrain" ? left : right);
    // 順番のある STEP に見えないよう、並列な「入口」を常に 3 案だけ返す
    const userMsgs = (task.chat || []).filter((m) => m.role === "user").map((m) => m.text);
    const ctx = userMsgs.slice(-2).join("、");
    const picked = pick(pool, ctx ? 2 : 3);
    if (ctx) {
      picked.unshift(`「${ctx}」を踏まえて: まずその条件で「${t}」の選択肢を1つだけ探してみる`);
    }
    return picked.slice(0, 3);
  }

  // チャットは「AIが凝った提案を考える」のではなく「ユーザー自身の言葉を
  // 最初の一歩に整えるのを支援する」役割（考えすぎ防止）。
  function polishStep(userText) {
    const t = userText.trim().replace(/[。！!]$/, "");
    if (/^(まず|とりあえず|最初に)/.test(t)) return t;
    return `まず5分だけ「${t}」をやってみる`;
  }

  function aiChatReply() {
    const replies = [
      `いいですね、それでいきましょう。下のボタンでそのまま決定できます`,
      `それぐらい小さくて十分です。決めちゃいましょう`,
      `OK、それを最初の一歩にしよか。ボタン押すだけやで`,
    ];
    return replies[Math.floor(Math.random() * replies.length)];
  }

  /* ---------- ブリーフィング文面（口調） ---------- */

  // ブリーフィング文面 = 今日やらないといけないタスクのざっくりまとめ ＋ 応援
  function briefingMessage(tasks) {
    // まとめ部分（軽い順に受け取ったタスクを要約）
    const names = tasks.map((t) => `「${t.title}」`).join("、");
    const dueNow = tasks.filter((t) => daysLeft(t.deadline) <= 0);
    let summary = `今日は${names}の${tasks.length}本立て。`;
    if (dueNow.length) {
      summary += `特に${dueNow.map((t) => `「${t.title}」`).join("と")}は今日が期限です。`;
    }

    // 応援部分（ハイブリッド口調: 基本やさしめ、ツッコミ設定なら確率を上げる。恥・人格否定は無し）
    const gentle = [
      `軽いものから5分だけ。それで十分前に進みます。応援してます！`,
      `全部やらなくて大丈夫。1つ動いたら今日は勝ちです。頑張ろう！`,
      `昨日の分は置いといて、今日の分だけでOK。あなたならいけます！`,
    ];
    const tsukkomi = [
      `やり始めたら意外と進むやつやで。まず5分、応援しとるで！`,
      `考える前にタイマー5分や。終わったら胸張ってええからな、頑張りや！`,
      `一番軽いやつからでええねん。今日もぼちぼちいこか、応援してるで！`,
    ];
    const tsukkomiRate = state.settings.tone === "tsukkomi" ? 0.7 : 0.25;
    const pool = Math.random() < tsukkomiRate ? tsukkomi : gentle;
    const cheer = pool[Math.floor(Math.random() * pool.length)];

    return `${summary}${cheer}`;
  }

  /* ---------- AIに相談（モック） ----------
     タスクの状況を踏まえて答える。実装時は全タスク＋設定をコンテキストに
     Gemini に渡す。恥・説教は禁止、常に「小さい入口」を添える。 */

  function consultReply(text) {
    const all = sortTasks([...state.tasks]);

    // 期限が近いタスクを聞かれた（今日・明日・締切系）
    if (/今日|明日|期限|締切|しめきり|やらないと|やるべき/.test(text)) {
      const urgent = all.filter((t) => daysLeft(t.deadline) <= 1);
      if (!urgent.length) {
        return "今日明日が期限のタスクはありません。余裕のある日です ☕ もし進めるなら、一番軽いものを5分だけどうですか。";
      }
      const lines = urgent.map((t) => {
        const d = daysLeft(t.deadline);
        const when = d < 0 ? `${-d}日超過` : d === 0 ? "今日" : "明日";
        return `・${t.title}（${PRIORITY[t.priority].label}・期限は${when}）`;
      });
      return `今日明日はこの${urgent.length}つです。軽い順に:\n${lines.join("\n")}\nまずは一番上を5分だけ、どうですか。`;
    }

    // やる気がしない・だるい系 → 責めずに一番軽い入口を渡す
    if (/だる|やる気|疲れ|しんど|眠い|むり|無理|めんどう|面倒/.test(text)) {
      if (!all.length) {
        return "だるい日はそれでOK。タスクもゼロなので、今日は堂々と休みましょう。";
      }
      const lightest = all[0];
      const step = lightest.firstStep || (lightest.suggestions[0] || "5分だけタイマーをセットする");
      return `だるい日はそれでOKです。全部やらなくていい。\nもし1つだけなら、一番軽い「${lightest.title}」を。\n入口はこれだけ:「${step}」\n5分やってダメなら、今日は店じまいで正解です。`;
    }

    // タスク一覧系
    if (/タスク|一覧|なにがある|何がある/.test(text)) {
      if (!all.length) return "タスクはゼロです 🎉";
      return `いま${all.length}件あります。軽い順に:\n${all.map((t) => `・${t.title}（${PRIORITY[t.priority].label}）`).join("\n")}`;
    }

    return "なんでも聞いてください。「今日やらないといけないのは？」でタスクを整理したり、「だるくてやる気がしない」って気分をこぼしてもらってもOKです。";
  }

  let consultTyping = false;

  function renderConsult() {
    const thread = $("#consultThread");
    const bubbles = (state.consult || []).map((m) =>
      `<div class="bubble ${m.role}">${esc(m.text)}</div>`).join("");
    const typing = consultTyping
      ? `<div class="bubble ai typing"><span></span><span></span><span></span></div>` : "";
    const empty = !(state.consult || []).length && !consultTyping
      ? `<div class="chat-hint">タスクのことも、気分のことも、なんでもどうぞ<br>（例:「今日明日でやらないといけないタスクは？」<br>「だるくてやる気がしない」）</div>` : "";
    thread.innerHTML = empty + bubbles + typing;
    thread.scrollTop = thread.scrollHeight;
  }

  function sendConsult() {
    const input = $("#consultInput");
    const text = input.value.trim();
    if (!text || consultTyping) return;
    input.value = "";
    state.consult.push({ role: "user", text });
    save();
    consultTyping = true;
    renderConsult();
    setTimeout(() => {
      state.consult.push({ role: "ai", text: consultReply(text) });
      consultTyping = false;
      save();
      renderConsult();
    }, 600 + Math.random() * 500);
  }

  /* ---------- ユーティリティ ---------- */

  function daysLeft(deadline) {
    const ms = new Date(deadline) - new Date(today());
    return Math.round(ms / 86400000);
  }

  function deadlineBadge(deadline) {
    const d = daysLeft(deadline);
    if (d < 0) return `<span class="badge deadline overdue">期限を${-d}日超過</span>`;
    if (d === 0) return `<span class="badge deadline today">今日が期限</span>`;
    return `<span class="badge deadline">あと${d}日</span>`;
  }

  function esc(s) {
    return s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  }

  const $ = (sel) => document.querySelector(sel);

  /* ---------- 画面遷移 ---------- */

  let currentScreen = "briefing";
  let detailTaskId = null;

  function showScreen(name) {
    currentScreen = name;
    document.querySelectorAll(".app-screen:not(.push-screen)").forEach((el) => {
      el.classList.toggle("active", el.id === `screen-${name}`);
    });
    document.querySelectorAll(".tab").forEach((el) => {
      el.classList.toggle("active", el.dataset.screen === name);
    });
    if (name === "briefing") renderBriefing();
    if (name === "list") renderList();
    if (name === "consult") renderConsult();
    if (name === "settings") renderSettings();
  }

  function openDetail(id) {
    detailTaskId = id;
    renderDetail();
    $("#screen-detail").classList.add("active", "open");
  }

  function closeDetail() {
    $("#screen-detail").classList.remove("open");
    setTimeout(() => $("#screen-detail").classList.remove("active"), 300);
    detailTaskId = null;
    renderList();
    renderBriefing();
  }

  /* ---------- 完了処理（完了＝削除） ---------- */

  function completeTask(id, cardEl) {
    if (cardEl) {
      cardEl.classList.add("done");
      setTimeout(() => {
        state.tasks = state.tasks.filter((t) => t.id !== id);
        save();
        renderList();
        renderBriefing();
      }, 380);
    } else {
      state.tasks = state.tasks.filter((t) => t.id !== id);
      save();
    }
  }

  /* ---------- レンダリング: 一覧 ---------- */

  // 軽い順（軽い→激重）に表示。一番軽いものから始めるとエンジンがかかる。
  // 同じ重さなら期限が近い順。
  function sortTasks(tasks) {
    return tasks.sort((a, b) =>
      PRIORITY[a.priority].weight - PRIORITY[b.priority].weight ||
      a.deadline.localeCompare(b.deadline));
  }

  /* ---------- 進捗度（v1.4: 0〜100%を25%刻み、充電池マークは表示専用） ---------- */

  function normalizeProgress(v) {
    if ([0, 25, 50, 75, 100].includes(v)) return v;
    if (v === 1) return 25; // 旧3段階(1/2/3)からの移行
    if (v === 2) return 50;
    if (v === 3) return 75;
    return 0;
  }

  function batteryHtml(t) {
    const bars = t.progress / 25; // 0〜4目盛り
    return `
      <span class="battery q${bars}" title="進捗 ${t.progress}%">
        <span class="bar"></span><span class="bar"></span><span class="bar"></span><span class="bar"></span>
      </span>`;
  }

  function taskCardHtml(t, { compact = false, showBrain = true } = {}) {
    return `
      <div class="task-card${compact ? " compact" : ""}" data-id="${t.id}">
        <div class="check-circle" data-check="${t.id}">✓</div>
        <div class="task-main">
          <div class="task-title">${esc(t.title)}</div>
          <div class="task-badges">
            ${batteryHtml(t)}
            ${showBrain ? `<span class="badge brain-${t.brainType}">${BRAIN[t.brainType]}</span>` : ""}
            <span class="badge p-${t.priority}">${PRIORITY[t.priority].label}</span>
            ${deadlineBadge(t.deadline)}
          </div>
        </div>
      </div>`;
  }

  function bindTaskCards(wrap) {
    wrap.querySelectorAll(".task-card").forEach((card) => {
      card.addEventListener("click", (e) => {
        if (e.target.dataset.check) return;
        openDetail(card.dataset.id);
      });
    });
    wrap.querySelectorAll(".check-circle").forEach((c) => {
      c.addEventListener("click", () => completeTask(c.dataset.check, c.closest(".task-card")));
    });
  }

  function renderList() {
    const wrap = $("#taskList");
    const filter = state.filter;

    const scrollEl = wrap.closest(".scroll");

    if (!state.tasks.length) {
      scrollEl.classList.remove("split");
      wrap.innerHTML = `<div class="empty-state"><span class="big">🎉</span>タスクゼロ！<br>「＋」から追加すると、AIが着手の入口をA・B・Cの3つ提案します</div>`;
      return;
    }

    if (filter === "all") {
      // 「すべて」= 画面を縦2分割。左半分＝左脳（青系）/ 右半分＝右脳（オレンジ系）
      scrollEl.classList.add("split");
      const left = sortTasks(state.tasks.filter((t) => t.brainType === "leftBrain"));
      const right = sortTasks(state.tasks.filter((t) => t.brainType === "rightBrain"));
      const colHtml = (tasks, emptyText) => tasks.length
        ? tasks.map((t) => taskCardHtml(t, { compact: true, showBrain: false })).join("")
        : `<div class="col-empty">${emptyText}</div>`;
      wrap.innerHTML = `
        <div class="brain-columns">
          <div class="brain-col left">
            <div class="brain-col-header">🧮 左脳<span class="col-count">${left.length}</span></div>
            ${colHtml(left, "論理・事務系は<br>ゼロ 🎉")}
          </div>
          <div class="brain-col right">
            <div class="brain-col-header">🎨 右脳<span class="col-count">${right.length}</span></div>
            ${colHtml(right, "創造・直感系は<br>ゼロ 🎉")}
          </div>
        </div>`;
      bindTaskCards(wrap);
      return;
    }

    scrollEl.classList.remove("split");

    const tasks = sortTasks(state.tasks.filter((t) => t.brainType === filter));
    if (!tasks.length) {
      wrap.innerHTML = `<div class="empty-state"><span class="big">🎉</span>このタイプのタスクはゼロ！</div>`;
      return;
    }
    wrap.innerHTML = tasks.map((t) => taskCardHtml(t)).join("");
    bindTaskCards(wrap);
  }

  /* ---------- レンダリング: ブリーフィング ---------- */

  let briefingText = null; // 画面を出入りしても文面が毎回変わりすぎないようキャッシュ

  function briefingPick() {
    // 期限の近さ × Priority でスコアリングし上位3件を選び、
    // 表示は「軽い順」（一番軽いものから始めるとエンジンがかかる）
    const picked = [...state.tasks]
      .sort((a, b) => {
        const sa = PRIORITY[a.priority].weight * 2 - daysLeft(a.deadline);
        const sb = PRIORITY[b.priority].weight * 2 - daysLeft(b.deadline);
        return sb - sa;
      })
      .slice(0, 3);
    return sortTasks(picked);
  }

  function renderBriefing() {
    const tasks = briefingPick();
    const msgEl = $("#briefingMessage");
    const cardsEl = $("#briefingCards");
    const dateStr = new Date().toLocaleDateString("ja-JP", { month: "long", day: "numeric", weekday: "short" });

    if (!tasks.length) {
      msgEl.innerHTML = `<div class="bm-date">${dateStr}　ADHTからのコメント</div>今日のタスクはありません。ゆっくりどうぞ ☕`;
      cardsEl.innerHTML = "";
      return;
    }
    if (!briefingText) briefingText = briefingMessage(tasks);
    msgEl.innerHTML = `
      <div class="bm-date">${dateStr}　ADHTからのコメント</div>
      <button class="bm-refresh" id="bmRefresh" title="ブリーフィングを更新">↻</button>
      ${esc(briefingText)}`;
    $("#bmRefresh").addEventListener("click", () => {
      briefingText = null; // 次の render で作り直し
      renderBriefing();
    });

    cardsEl.innerHTML = tasks.map((t) => `
      <div class="briefing-card" data-id="${t.id}">
        <div class="bc-top"><div class="bc-title">${esc(t.title)}</div></div>
        <div class="bc-first-step">
          <span class="fs-label">${t.firstStep ? "👣 決定した最初の一歩" : "最初の一歩（AI提案）"}</span>
          ${esc(t.firstStep || t.suggestions[0] || "まず5分だけタイマーをセットして着手")}
        </div>
        <div class="bc-meta">
          ${batteryHtml(t)}
          <span class="badge p-${t.priority}">${PRIORITY[t.priority].label}</span>
          <span class="badge deadline">${PRIORITY[t.priority].time}</span>
          ${deadlineBadge(t.deadline)}
        </div>
        <div class="bc-actions">
          <button class="bc-done-btn" data-done="${t.id}">✓ 完了</button>
          <button class="bc-open-btn" data-open="${t.id}">提案を見る</button>
        </div>
      </div>`).join("");

    cardsEl.querySelectorAll("[data-done]").forEach((b) => {
      b.addEventListener("click", () => completeTask(b.dataset.done, b.closest(".briefing-card")));
    });
    cardsEl.querySelectorAll("[data-open]").forEach((b) => {
      b.addEventListener("click", () => openDetail(b.dataset.open));
    });
    // カード本体のタップでもタスク詳細へ（ボタン類は除く）
    cardsEl.querySelectorAll(".briefing-card").forEach((card) => {
      card.addEventListener("click", (e) => {
        if (e.target.closest("button")) return;
        openDetail(card.dataset.id);
      });
    });
  }

  /* ---------- レンダリング: 詳細 ---------- */

  let aiTyping = false;

  function renderDetail(loading = false) {
    const t = state.tasks.find((x) => x.id === detailTaskId);
    const body = $("#detailBody");
    if (!t) { body.innerHTML = ""; return; }

    // 最初の一歩: 決定済みなら決定カード、未決定なら A/B/C から選ぶ
    let stepSection;
    if (loading) {
      stepSection = `
        <div class="section-label">🤖 最初の一歩（AI提案）</div>
        <div class="ai-loading"><div class="spinner"></div>AIが最初の一歩を考えています…</div>`;
    } else if (t.firstStep) {
      stepSection = `
        <div class="section-label">👣 決定した最初の一歩</div>
        <div class="decided-step">
          <div class="decided-text">${esc(t.firstStep)}</div>
          <button class="step-reset" id="stepReset">選び直す</button>
        </div>`;
    } else {
      stepSection = `
        <div class="section-label">🤖 最初の一歩（AI提案）</div>
        <div class="suggestion-list">
          ${t.suggestions.slice(0, 3).map((s, i) => `
            <div class="suggestion-item pickable" data-pick="${i}">
              <span class="suggestion-num">${"ABC"[i]}</span><span>${esc(s)}</span>
              <span class="pick-pill">これ</span>
            </div>`).join("")}
        </div>
        <p class="pick-hint">タップで決定。しっくりこなければ下のAIと相談</p>`;
    }

    const bubbles = (t.chat || []).map((m, idx) => {
      let inner = esc(m.text);
      if (m.role === "ai" && m.proposal) {
        inner += `
          <div class="bubble-proposal">
            ${esc(m.proposal)}
            <button class="adopt-btn" data-adopt="${idx}">👣 これを最初の一歩にする</button>
          </div>`;
      }
      return `<div class="bubble ${m.role}">${inner}</div>`;
    }).join("");
    const typingHtml = aiTyping
      ? `<div class="bubble ai typing"><span></span><span></span><span></span></div>` : "";
    const chatEmpty = !(t.chat || []).length && !aiTyping
      ? `<div class="chat-hint">自分の言葉で書けば、それがそのまま最初の一歩になります<br>（例:「レシートを机に出すだけ」）</div>` : "";

    body.innerHTML = `
      <div class="detail-title">${esc(t.title)}</div>
      <div class="detail-badges">
        ${batteryHtml(t)}
        <span class="badge brain-${t.brainType}">${BRAIN[t.brainType]}</span>
        <span class="badge p-${t.priority}">${PRIORITY[t.priority].label}</span>
        ${deadlineBadge(t.deadline)}
      </div>

      <div class="section-label">🔋 進捗</div>
      <div class="progress-card">
        <div class="progress-row">
          <input type="range" id="progressSlider" min="0" max="100" step="25" value="${t.progress}">
          <span class="progress-val" id="progressVal">${t.progress}%</span>
        </div>
        <div class="progress-ticks"><span>0</span><span>25</span><span>50</span><span>75</span><span>100</span></div>
      </div>

      ${stepSection}

      <div class="section-label">💬 AIと話して最初の一歩を決める</div>
      <div class="chat-box">
        <div class="chat-thread" id="chatThread">${chatEmpty}${bubbles}${typingHtml}</div>
        <div class="chat-input-row">
          <input type="text" id="chatInput" placeholder="やれそうなことを自分の言葉で…" ${aiTyping ? "disabled" : ""}>
          <button id="chatSend" ${aiTyping ? "disabled" : ""}>↑</button>
        </div>
      </div>

      <button class="detail-done-btn" id="detailDone">✓ このタスクを完了する（リストから消えます）</button>
    `;

    // A/B/C タップで決定 — 選んだ行がその場で「決定した一歩」に変化してから確定表示へ
    body.querySelectorAll("[data-pick]").forEach((el) => {
      el.addEventListener("click", () => {
        if (el.classList.contains("picked")) return;
        el.classList.add("picked");
        el.querySelector(".pick-pill").textContent = "👣 決定！";
        el.querySelector(".suggestion-num").textContent = "✓";
        el.parentElement.querySelectorAll(".suggestion-item").forEach((row) => {
          if (row !== el) row.classList.add("dimmed");
        });
        setTimeout(() => {
          t.firstStep = t.suggestions[Number(el.dataset.pick)];
          save();
          renderDetail(false);
          renderBriefing();
        }, 550);
      });
    });
    // 決定を解除して選び直す
    const resetBtn = $("#stepReset");
    if (resetBtn) resetBtn.addEventListener("click", () => {
      t.firstStep = null;
      save();
      renderDetail(false);
      renderBriefing();
    });
    // チャット内の提案を採用
    body.querySelectorAll("[data-adopt]").forEach((el) => {
      el.addEventListener("click", () => {
        const m = t.chat[Number(el.dataset.adopt)];
        if (m && m.proposal) {
          t.firstStep = m.proposal;
          save();
          renderDetail(false);
          renderBriefing();
        }
      });
    });
    // 進捗スライダー（0/25/50/75/100%、電池マークは表示専用）
    const slider = $("#progressSlider");
    slider.addEventListener("input", () => {
      $("#progressVal").textContent = `${slider.value}%`;
      const batt = body.querySelector(".detail-badges .battery");
      if (batt) {
        batt.className = `battery q${Number(slider.value) / 25}`;
        batt.title = `進捗 ${slider.value}%`;
      }
    });
    slider.addEventListener("change", () => {
      t.progress = Number(slider.value);
      save();
      renderList();
      renderBriefing();
    });

    const thread = $("#chatThread");
    thread.scrollTop = thread.scrollHeight;

    const sendChat = () => {
      const input = $("#chatInput");
      const text = input.value.trim();
      if (!text || aiTyping) return;
      t.chat.push({ role: "user", text });
      save();
      aiTyping = true;
      renderDetail(false);
      setTimeout(() => {
        // ユーザー自身の言葉を軽く整えて「最初の一歩」候補として返す
        // （A・B・C はいじらない — チャットは入力支援に徹する）
        t.chat.push({ role: "ai", text: aiChatReply(), proposal: polishStep(text) });
        aiTyping = false;
        save();
        renderDetail(false);
      }, 500 + Math.random() * 400);
    };
    $("#chatSend").addEventListener("click", sendChat);
    $("#chatInput").addEventListener("keydown", (e) => { if (e.key === "Enter") sendChat(); });

    $("#detailDone").addEventListener("click", () => {
      completeTask(t.id);
      closeDetail();
    });
  }

  /* ---------- レンダリング: 設定 ---------- */

  function renderSettings() {
    document.querySelectorAll("#toneSetting button").forEach((b) => {
      b.classList.toggle("active", b.dataset.tone === state.settings.tone);
    });
    $("#briefingHour").value = state.settings.briefingHour;
  }

  /* ---------- 作成・編集シート ---------- */

  const draft = { title: "", brainType: null, priority: null, deadline: "", editingId: null };

  function openSheet(editTask = null) {
    draft.editingId = editTask ? editTask.id : null;
    draft.title = editTask ? editTask.title : "";
    draft.brainType = editTask ? editTask.brainType : null;
    draft.priority = editTask ? editTask.priority : null;
    draft.deadline = editTask ? editTask.deadline : today(1);
    $("#sheetTitle").textContent = editTask ? "タスクを編集" : "新しいタスク";
    $("#inTitle").value = draft.title;
    $("#inDeadline").value = draft.deadline;
    document.querySelectorAll("#inBrain button").forEach((b) =>
      b.classList.toggle("active", b.dataset.value === draft.brainType));
    document.querySelectorAll("#inPriority button").forEach((b) =>
      b.classList.toggle("active", b.dataset.value === draft.priority));
    validateDraft();
    $("#sheet-backdrop").classList.add("open");
    $("#sheet-create").classList.add("open");
    if (!editTask) setTimeout(() => $("#inTitle").focus(), 350);
  }

  function closeSheet() {
    $("#sheet-backdrop").classList.remove("open");
    $("#sheet-create").classList.remove("open");
  }

  function validateDraft() {
    const ok = draft.title.trim() && draft.brainType && draft.priority && draft.deadline;
    $("#createSave").disabled = !ok;
  }

  function saveDraft() {
    // 編集モード: 既存タスクを更新（タイトル/脳タイプが変わったら提案を作り直す）
    if (draft.editingId) {
      const t = state.tasks.find((x) => x.id === draft.editingId);
      if (t) {
        const needsRegen =
          t.title !== draft.title.trim() || t.brainType !== draft.brainType;
        t.title = draft.title.trim();
        t.brainType = draft.brainType;
        t.priority = draft.priority;
        t.deadline = draft.deadline;
        save();
        closeSheet();
        renderList();
        renderBriefing();
        if (needsRegen) {
          t.firstStep = null;
          renderDetail(true);
          setTimeout(() => {
            t.suggestions = generateSuggestions(t);
            save();
            renderDetail(false);
            renderBriefing();
          }, 900 + Math.random() * 600);
        } else {
          renderDetail(false);
        }
      }
      return;
    }

    const t = mkTask(draft.title.trim(), draft.brainType, draft.priority, draft.deadline);
    state.tasks.push(t);
    save();
    closeSheet();
    renderList();
    // 保存と同時にAI提案を自動生成（仕様 §2.2）— 詳細画面へ遷移してローディング表示
    detailTaskId = t.id;
    $("#screen-detail").classList.add("active", "open");
    renderDetail(true);
    setTimeout(() => {
      t.suggestions = generateSuggestions(t);
      save();
      renderDetail(false);
      renderBriefing();
    }, 1100 + Math.random() * 700);
  }

  /* ---------- イベント配線 ---------- */

  document.querySelectorAll(".tab").forEach((b) => {
    b.addEventListener("click", () => showScreen(b.dataset.screen));
  });

  document.querySelectorAll("#brainFilter button").forEach((b) => {
    b.addEventListener("click", () => {
      state.filter = b.dataset.filter;
      document.querySelectorAll("#brainFilter button").forEach((x) => x.classList.toggle("active", x === b));
      save();
      renderList();
    });
  });

  $("#fabAdd").addEventListener("click", openSheet);
  $("#createCancel").addEventListener("click", closeSheet);
  $("#sheet-backdrop").addEventListener("click", closeSheet);
  $("#createSave").addEventListener("click", saveDraft);

  $("#inTitle").addEventListener("input", (e) => { draft.title = e.target.value; validateDraft(); });
  $("#inDeadline").addEventListener("change", (e) => { draft.deadline = e.target.value; validateDraft(); });

  document.querySelectorAll("#inBrain button").forEach((b) => {
    b.addEventListener("click", () => {
      draft.brainType = b.dataset.value;
      document.querySelectorAll("#inBrain button").forEach((x) => x.classList.toggle("active", x === b));
      validateDraft();
    });
  });
  document.querySelectorAll("#inPriority button").forEach((b) => {
    b.addEventListener("click", () => {
      draft.priority = b.dataset.value;
      document.querySelectorAll("#inPriority button").forEach((x) => x.classList.toggle("active", x === b));
      validateDraft();
    });
  });

  $("#detailBack").addEventListener("click", closeDetail);
  $("#detailEdit").addEventListener("click", () => {
    const t = state.tasks.find((x) => x.id === detailTaskId);
    if (t) openSheet(t);
  });
  $("#detailDelete").addEventListener("click", () => {
    if (detailTaskId) {
      state.tasks = state.tasks.filter((t) => t.id !== detailTaskId);
      save();
    }
    closeDetail();
  });

  document.querySelectorAll("#toneSetting button").forEach((b) => {
    b.addEventListener("click", () => {
      state.settings.tone = b.dataset.tone;
      briefingText = null; // 口調変更は次のブリーフィング文面に反映
      save();
      renderSettings();
    });
  });
  $("#briefingHour").addEventListener("change", (e) => {
    state.settings.briefingHour = e.target.value;
    save();
  });

  /* ---------- iOS風ダイアログ ---------- */

  function showDialog({ title, message, okLabel = "OK", onOk, onCancel }) {
    $("#dialogTitle").textContent = title;
    $("#dialogMsg").textContent = message;
    $("#dialogOk").textContent = okLabel;
    const backdrop = $("#dialog-backdrop");
    backdrop.classList.add("open");

    const close = () => {
      backdrop.classList.remove("open");
      $("#dialogOk").onclick = null;
      $("#dialogCancel").onclick = null;
    };
    $("#dialogOk").onclick = () => { close(); if (onOk) onOk(); };
    $("#dialogCancel").onclick = () => { close(); if (onCancel) onCancel(); };
  }

  /* ---------- インポート / エクスポート（JSONコピペ, 仕様 §2.4） ---------- */

  const VALID_BRAIN = ["rightBrain", "leftBrain"];
  const VALID_PRIORITY = Object.keys(PRIORITY);

  function setIoStatus(msg, isError = false) {
    const el = $("#ioStatus");
    el.textContent = msg;
    el.style.color = isError ? "var(--ios-red)" : "var(--ios-green)";
  }

  function buildExportJson() {
    return JSON.stringify({
      format: "adht-tasks",
      version: EXPORT_FORMAT_VERSION,
      exportedAt: new Date().toISOString(),
      tasks: state.tasks,
    }, null, 2);
  }

  // エクスポート①: クリップボードにコピー
  $("#exportCopyBtn").addEventListener("click", () => {
    const json = buildExportJson();
    $("#ioArea").value = json;
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(json)
        .then(() => setIoStatus(`✓ ${state.tasks.length}件をクリップボードにコピーしました`))
        .catch(() => setIoStatus(`✓ ${state.tasks.length}件を下の欄に出しました（手動でコピーしてください）`));
    } else {
      setIoStatus(`✓ ${state.tasks.length}件を下の欄に出しました（手動でコピーしてください）`);
    }
  });

  // エクスポート②: JSONファイルとして保存
  $("#exportFileBtn").addEventListener("click", () => {
    const blob = new Blob([buildExportJson()], { type: "application/json" });
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = `adht-tasks-${today(0)}.json`;
    a.click();
    URL.revokeObjectURL(a.href);
    setIoStatus(`✓ ${state.tasks.length}件を ${a.download} として保存しました`);
  });

  // インポート共通処理（貼り付け / ファイル選択の両方から呼ぶ）
  function runImport(raw) {
    raw = (raw || "").trim();
    if (!raw) { setIoStatus("インポートするJSONを貼り付けてください", true); return; }

    let parsed;
    try {
      parsed = JSON.parse(raw);
    } catch (_) {
      setIoStatus("JSONとして読めませんでした。コピペが途中で切れていないか確認してください", true);
      return;
    }

    // エンベロープ形式 / 素のタスク配列のどちらも受け付ける
    const rawTasks = Array.isArray(parsed) ? parsed : parsed.tasks;
    if (parsed && !Array.isArray(parsed) && parsed.format && parsed.format !== "adht-tasks") {
      setIoStatus(`知らない形式です（format: ${parsed.format}）。何も変更していません`, true);
      return;
    }
    // 互換ルール: 古い形式（v1 = アプリv1.3.0以前）は取り込める。
    // 自分より新しい形式へのダウングレードインポートは非対応。
    if (parsed && !Array.isArray(parsed) && typeof parsed.version === "number" &&
        parsed.version > EXPORT_FORMAT_VERSION) {
      setIoStatus(`このJSONはより新しい形式（version ${parsed.version}）です。アプリを更新してからインポートしてください`, true);
      return;
    }
    if (!Array.isArray(rawTasks)) {
      setIoStatus("tasks の配列が見つかりません。何も変更していません", true);
      return;
    }

    // バリデーション＋欠けたフィールドをデフォルト補完（旧バージョンJSONのマイグレーション）
    const imported = [];
    for (const r of rawTasks) {
      if (!r || typeof r.title !== "string" || !r.title.trim()) {
        setIoStatus("title のないタスクが含まれています。何も変更していません", true);
        return;
      }
      imported.push({
        id: typeof r.id === "string" ? r.id : crypto.randomUUID(),
        title: r.title.trim(),
        brainType: VALID_BRAIN.includes(r.brainType) ? r.brainType : "leftBrain",
        priority: VALID_PRIORITY.includes(r.priority) ? r.priority : "futsuu",
        deadline: /^\d{4}-\d{2}-\d{2}$/.test(r.deadline || "") ? r.deadline : today(1),
        chat: Array.isArray(r.chat) ? r.chat : [],
        suggestions: Array.isArray(r.suggestions) ? r.suggestions.slice(0, 3) : [],
        firstStep: typeof r.firstStep === "string" ? r.firstStep : null,
        progress: normalizeProgress(r.progress), // v1(進捗なし)は0で補完、旧3段階は%へ変換
        createdAt: r.createdAt || new Date().toISOString(),
      });
    }

    showDialog({
      title: "タスクをインポート",
      message: `${imported.length}件のタスクを取り込みます。\n既存の${state.tasks.length}件は置き換えられます。`,
      okLabel: "インポート",
      onOk: () => {
        state.tasks = imported;
        briefingText = null;
        save();
        renderList();
        renderBriefing();
        setIoStatus(`✓ ${imported.length}件のタスクをインポートしました`);
      },
      onCancel: () => setIoStatus("インポートをキャンセルしました"),
    });
  }

  // インポート①: テキスト欄の貼り付けから
  $("#importPasteBtn").addEventListener("click", () => runImport($("#ioArea").value));

  // インポート②: JSONファイルを選択
  $("#importFileBtn").addEventListener("click", () => $("#importFileInput").click());
  $("#importFileInput").addEventListener("change", (e) => {
    const file = e.target.files[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      $("#ioArea").value = reader.result;
      runImport(reader.result);
    };
    reader.onerror = () => setIoStatus("ファイルを読み込めませんでした", true);
    reader.readAsText(file);
    e.target.value = ""; // 同じファイルを続けて選べるようにリセット
  });

  $("#consultSend").addEventListener("click", sendConsult);
  $("#consultInput").addEventListener("keydown", (e) => { if (e.key === "Enter") sendConsult(); });

  $("#resetBtn").addEventListener("click", () => {
    if (confirm("サンプルデータに戻しますか？")) {
      briefingText = null;
      initState();
      showScreen("briefing");
      renderList();
    }
  });

  /* ---------- 起動 ---------- */

  document.querySelectorAll("#brainFilter button").forEach((x) => {
    x.classList.toggle("active", x.dataset.filter === (state.filter || "all"));
  });
  $("#appVersion").textContent = `ADHT v${APP_VERSION}`;
  document.querySelector(".proto-header span").textContent =
    `ADHT プロトタイプ v${APP_VERSION} ／ iPhone 17 モック（AI提案はモック生成・データは localStorage 保存）`;
  const hash = location.hash.slice(1);
  const initial = ["briefing", "list", "consult", "settings"].includes(hash) ? hash : "briefing";
  showScreen(initial);
  renderList();
  if (hash === "detail" && state.tasks.length) openDetail(state.tasks[0].id); // 動作確認用
  if (hash === "consult" && !state.consult.length) { // 動作確認用デモ会話
    state.consult = [
      { role: "user", text: "今日明日でやらないといけないタスクはなに？" },
      { role: "ai", text: consultReply("今日明日でやらないといけないタスクはなに？") },
      { role: "user", text: "だるくてやる気がしない" },
      { role: "ai", text: consultReply("だるくてやる気がしない") },
    ];
    renderConsult();
  }
  if (hash === "dialog") { // 動作確認用
    showScreen("settings");
    showDialog({
      title: "タスクをインポート",
      message: "4件のタスクを取り込みます。\n既存の4件は置き換えられます。",
      okLabel: "インポート",
    });
  }
})();
