const DATA = window.KS_DATA || {
  catalog: [],
  curricula: [],
  subjectProfiles: {},
  fallbackProfile: {
    domains: ["개념", "탐구", "적용", "표현"],
    focus: ["핵심 개념", "자료 해석", "개념 적용", "오답 점검"],
    summary: "학년 수준에 맞는 핵심 개념을 정리하고 문제 상황에 적용하는 연습을 합니다.",
    formula: "학습 루틴 = 개념 이해 + 예시 확인 + 문제 적용 + 오답 정리"
  },
  unitSeeds: {},
  questionTemplates: {}
};

const state = {
  result: null,
  theme: localStorage.getItem("ks_theme") || "light"
};

const $ = (id) => document.getElementById(id);

function init() {
  document.documentElement.dataset.theme = state.theme;
  fillSchoolOptions();
  fillCurriculumOptions();
  renderDataStats();
  renderGovernance();
  renderDeployReadiness();
  renderQaChecklist();
  renderFinalApprovals();
  loadSettings();
  bindEvents();
  generateMaterial();
  renderLibrary();
  renderMistakes();
  renderExplore();
}

function bindEvents() {
  $("schoolLevel").addEventListener("change", () => {
    fillGradeOptions();
    fillSubjectOptions();
    fillUnitOptions();
  });
  $("subject").addEventListener("change", fillUnitOptions);
  $("generateBtn").addEventListener("click", generateMaterial);
  $("worksheetBtn").addEventListener("click", () => {
    renderWorksheet();
    switchView("worksheet");
  });
  $("printBtn").addEventListener("click", () => window.print());
  $("downloadBtn").addEventListener("click", downloadCurrent);
  $("regenerateQuestions").addEventListener("click", () => {
    state.result.format = $("questionFormat").value;
    state.result.questions = makeQuestions(state.result.subject, profileFor(state.result.subject), $("questionCategory").value, $("questionFormat").value);
    renderQuestions();
  });
  $("saveBtn").addEventListener("click", saveCurrent);
  $("clearLibrary").addEventListener("click", clearLibrary);
  $("clearMistakes").addEventListener("click", clearMistakes);
  $("saveSettings").addEventListener("click", saveSettings);
  $("forgetSettings").addEventListener("click", forgetSettings);
  $("themeToggle").addEventListener("click", toggleTheme);
  $("runSelfCheck").addEventListener("click", runSelfCheck);
  $("textbookForm").addEventListener("submit", handleTextbook);
  $("questionList").addEventListener("click", toggleAnswer);
  $("questionList").addEventListener("click", handleMistakeSave);
  $("mistakeList").addEventListener("click", handleMistakeAction);
  $("exploreSearch").addEventListener("input", renderExplore);
  $("exploreResults").addEventListener("click", handleExplorePick);

  document.querySelectorAll("[data-view]").forEach((button) => {
    button.addEventListener("click", () => switchView(button.dataset.view));
  });
}

function fillSchoolOptions() {
  const catalog = DATA.catalog.length ? DATA.catalog : [{ school: "고등학교", grades: [1], subjects: ["공통수학"] }];
  $("schoolLevel").innerHTML = catalog.map((item) => `<option>${item.school}</option>`).join("");
  fillGradeOptions();
  fillSubjectOptions();
}

function currentSchool() {
  return DATA.catalog.find((item) => item.school === $("schoolLevel").value) || DATA.catalog[0];
}

function fillGradeOptions() {
  const school = currentSchool();
  $("grade").innerHTML = (school?.grades || [1]).map((grade) => `<option value="${grade}">${grade}학년</option>`).join("");
}

function fillSubjectOptions() {
  const school = currentSchool();
  $("subject").innerHTML = (school?.subjects || ["공통수학"]).map((subject) => `<option>${subject}</option>`).join("");
  fillUnitOptions();
}

function fillCurriculumOptions() {
  const curricula = DATA.curricula.length ? DATA.curricula : [{ id: "2022", name: "2022 개정" }];
  $("curriculum").innerHTML = curricula.map((item) => `<option value="${item.id}">${item.name}</option>`).join("");
}

function fillUnitOptions() {
  const units = unitsFor($("schoolLevel").value, $("subject").value);
  $("unitSelect").innerHTML = units.map((unit) => `<option>${unit}</option>`).join("");
}

function switchView(view) {
  document.querySelectorAll(".view").forEach((el) => el.classList.toggle("active", el.id === view));
  document.querySelectorAll(".tab, .bottom-nav button").forEach((el) => {
    el.classList.toggle("active", el.dataset.view === view);
  });
}

function renderDataStats() {
  const schoolCount = DATA.catalog.length;
  const subjectCount = new Set(DATA.catalog.flatMap((school) => school.subjects)).size;
  const unitCount = DATA.catalog.reduce((sum, school) => {
    return sum + school.subjects.reduce((inner, subject) => inner + unitsFor(school.school, subject).length, 0);
  }, 0);
  $("dataStats").innerHTML = [
    ["학교급", `${schoolCount}개`],
    ["과목", `${subjectCount}개`],
    ["단원 시드", `${unitCount}개`],
    ["문제 유형", "4종"]
  ].map(([label, value]) => `
    <div class="stat">
      <strong>${escapeHtml(value)}</strong>
      <span>${escapeHtml(label)}</span>
    </div>
  `).join("");
}

function renderGovernance() {
  const governance = DATA.dataGovernance || { status: "미정", lastUpdated: "", verification: [] };
  const manifest = window.KS_DATA_MANIFEST;
  $("governancePanel").innerHTML = `
    <article class="governance-card full">
      <strong>${escapeHtml(governance.status)}</strong>
      <span>마지막 업데이트: ${escapeHtml(governance.lastUpdated || "기록 없음")}</span>
    </article>
    ${governance.verification.map((item) => `
      <article class="governance-card">
        <div class="state">${escapeHtml(item.state)}</div>
        <h3>${escapeHtml(item.label)}</h3>
        <p>${escapeHtml(item.detail)}</p>
      </article>
    `).join("")}
    ${manifest ? `
      <article class="governance-card full">
        <strong>데이터 구조 ${escapeHtml(manifest.version)}</strong>
        <span>${escapeHtml(manifest.mode)} · ${escapeHtml(manifest.currentRuntimeFile)}</span>
      </article>
      ${manifest.splitPlan.slice(0, 4).map((item) => `
        <article class="governance-card">
          <div class="state">분리 계획</div>
          <h3>${escapeHtml(item.file)}</h3>
          <p>${escapeHtml(item.purpose)}</p>
        </article>
      `).join("")}
    ` : ""}
  `;
}

function renderDeployReadiness() {
  const items = DATA.deploymentReadiness || [];
  $("deployPanel").innerHTML = items.map((item) => `
    <article class="governance-card">
      <div class="state">${escapeHtml(item.state)}</div>
      <h3>${escapeHtml(item.item)}</h3>
      <p>${escapeHtml(item.detail)}</p>
    </article>
  `).join("") || `<p class="notice">배포 준비 상태 데이터가 없습니다.</p>`;
}

function renderQaChecklist() {
  const groups = DATA.qaChecklist || [];
  $("qaPanel").innerHTML = groups.map((group) => `
    <article class="qa-card">
      <h3>${escapeHtml(group.group)}</h3>
      <ul>
        ${group.items.map((item) => `<li><span aria-hidden="true">□</span>${escapeHtml(item)}</li>`).join("")}
      </ul>
    </article>
  `).join("") || `<p class="notice">QA 체크리스트가 없습니다.</p>`;
}

function renderFinalApprovals() {
  const groups = DATA.finalApprovals || [];
  $("approvalPanel").innerHTML = groups.map((group) => `
    <article class="qa-card approval-card">
      <h3>${escapeHtml(group.category)}</h3>
      <ul>
        ${group.items.map((item) => `<li><span aria-hidden="true">□</span>${escapeHtml(item)}</li>`).join("")}
      </ul>
    </article>
  `).join("") || `<p class="notice">최종 승인 항목이 없습니다.</p>`;
}

function runSelfCheck() {
  const requiredIds = [
    "schoolLevel", "grade", "subject", "unitSelect", "questionCategory", "questionFormat",
    "summaryContent", "conceptTable", "mindmapCanvas", "questionList", "libraryList",
    "mistakeList", "worksheetContent", "governancePanel", "deployPanel", "qaPanel"
  ];
  const checks = [
    {
      label: "필수 화면 요소",
      ok: requiredIds.every((id) => Boolean($(id))),
      detail: `${requiredIds.filter((id) => !$(id)).length}개 누락`
    },
    {
      label: "교육 데이터",
      ok: DATA.catalog.length > 0 && Object.keys(DATA.subjectProfiles).length > 0,
      detail: `${DATA.catalog.length}개 학교급, ${Object.keys(DATA.subjectProfiles).length}개 과목 프로필`
    },
    {
      label: "단원 데이터",
      ok: Object.keys(DATA.unitSeeds || {}).length > 0,
      detail: `${Object.keys(DATA.unitSeeds || {}).length}개 학교급 단원 시드`
    },
    {
      label: "문제 템플릿",
      ok: ["concept", "school", "mock", "essay"].every((key) => Array.isArray(DATA.questionTemplates?.[key])),
      detail: "개념/내신/모의고사/서술형 템플릿"
    },
    {
      label: "생성 결과",
      ok: Boolean(state.result?.summary && state.result?.questions?.length),
      detail: state.result ? `${state.result.title} · ${state.result.questions.length}문항` : "결과 없음"
    },
    {
      label: "브라우저 저장소",
      ok: storageAvailable(),
      detail: "localStorage 접근"
    }
  ];
  const passed = checks.filter((check) => check.ok).length;
  $("selfCheckPanel").innerHTML = `
    <article class="self-check-summary">
      <strong>${passed}/${checks.length} 통과</strong>
      <span>${new Date().toLocaleString("ko-KR")}</span>
    </article>
    <div class="self-check-list">
      ${checks.map((check) => `
        <div class="self-check-item ${check.ok ? "pass" : "fail"}">
          <strong>${check.ok ? "통과" : "확인 필요"}</strong>
          <span>${escapeHtml(check.label)} · ${escapeHtml(check.detail)}</span>
        </div>
      `).join("")}
    </div>
  `;
}

function storageAvailable() {
  try {
    const key = "ks_self_check";
    localStorage.setItem(key, "ok");
    localStorage.removeItem(key);
    return true;
  } catch {
    return false;
  }
}

function renderExplore() {
  const query = ($("exploreSearch")?.value || "").trim().toLowerCase();
  const rows = [];
  DATA.catalog.forEach((school) => {
    school.subjects.forEach((subject) => {
      unitsFor(school.school, subject).forEach((unit) => {
        const label = `${school.school} ${subject} ${unit}`.toLowerCase();
        if (!query || label.includes(query)) {
          rows.push({ school: school.school, subject, unit });
        }
      });
    });
  });

  $("exploreResults").innerHTML = rows.slice(0, 40).map((row) => `
    <button class="explore-item" data-school="${escapeHtml(row.school)}" data-subject="${escapeHtml(row.subject)}" data-unit="${escapeHtml(row.unit)}" type="button">
      <strong>${escapeHtml(row.school)} · ${escapeHtml(row.subject)}</strong>
      <span>${escapeHtml(row.unit)}</span>
    </button>
  `).join("") || `<p class="notice">검색 결과가 없습니다.</p>`;
}

function handleExplorePick(event) {
  const item = event.target.closest(".explore-item");
  if (!item) return;
  $("schoolLevel").value = item.dataset.school;
  fillGradeOptions();
  fillSubjectOptions();
  $("subject").value = item.dataset.subject;
  fillUnitOptions();
  $("unitSelect").value = item.dataset.unit;
  generateMaterial();
  switchView("summary");
}

function profileFor(subject) {
  const normalized = subject.replace(/[ⅠⅡⅢ]/g, "");
  return DATA.subjectProfiles[subject] || DATA.subjectProfiles[normalized] || DATA.fallbackProfile;
}

function unitsFor(school, subject) {
  const schoolUnits = DATA.unitSeeds?.[school] || {};
  const normalized = subject.replace(/[ⅠⅡⅢ]/g, "");
  return schoolUnits[subject] || schoolUnits[normalized] || profileFor(subject).domains || ["주요 개념"];
}

async function generateMaterial(extra = {}) {
  const school = $("schoolLevel").value;
  const grade = $("grade").value;
  const subject = $("subject").value;
  const category = $("questionCategory").value;
  const format = $("questionFormat").value;
  const curriculum = $("curriculum").value || "2022";
  const selectedUnit = $("unitSelect").value || "";
  const base = buildLocalMaterial({ school, grade, subject, category, format, curriculum, unit: selectedUnit, ...extra });
  state.result = base;
  renderAll();

  try {
    const ai = await requestGemini(base);
    if (ai?.summary) {
      state.result = mergeAiResult(base, ai);
      renderAll();
    }
  } catch (error) {
    console.info("Gemini fallback used:", error.message);
  }
}

function buildLocalMaterial({ school, grade, subject, category, format = "mixed", curriculum, publisher = "", author = "", unit = "", userText = "" }) {
  const profile = profileFor(subject);
  const units = unitsFor(school, subject);
  const unitText = unit ? `${unit} 단원` : `${units[0] || "주요"} 단원`;
  const curriculumInfo = DATA.curricula.find((item) => item.id === curriculum);
  const title = `${school} ${grade}학년 ${subject}`;
  const textbookNote = publisher || author ? `${publisher || "출판사 미입력"} · ${author || "저자 미입력"}` : "교육과정 기반";

  return {
    title,
    school,
    grade,
    subject,
    category,
    format,
    curriculum: curriculumInfo?.name || curriculum,
    unit: unitText,
    textbookNote,
    summary: `${title}(${curriculumInfo?.name || curriculum})에서는 ${profile.summary} ${unitText} 학습에서는 개념의 정의, 대표 예시, 자주 틀리는 조건을 함께 정리하는 것이 중요합니다.`,
    goal: `${unitText}의 핵심 개념을 설명하고, 대표 문제나 사례에 적용할 수 있습니다.`,
    achievement: "공식 성취기준 원문은 나중에 공식 자료 대조 후 연결합니다. 현재는 학습 목표형 메모로 제공합니다.",
    keywords: profile.focus,
    formula: profile.formula,
    userText,
    routine: routineFor(subject),
    tips: tipsFor(subject),
    examFocus: examFocusFor(subject),
    table: profile.focus.map((focus, index) => ({
      name: focus,
      content: `${focus}의 정의와 대표 사례를 확인합니다. 관련 단원: ${units[index % units.length] || unitText}`,
      point: index % 2 === 0 ? "개념을 말로 설명한 뒤 예시 문제에 적용합니다." : "비슷한 개념과 차이점을 표로 비교합니다."
    })),
    mindmap: profile.focus.map((focus) => ({
      name: focus,
      detail: `${subject} 학습에서 ${focus}를 중심 개념, 예시, 문제 유형으로 나눠 정리합니다.`
    })),
    questions: makeQuestions(subject, profile, category, format)
  };
}

function makeQuestions(subject, profile, category, format = "mixed") {
  const labels = {
    concept: "개념 확인",
    school: "내신 대비",
    mock: "모의고사 대비",
    essay: "서술형/수행평가"
  };
  const label = labels[category] || labels.concept;
  const templates = DATA.questionTemplates?.[category] || [];

  const source = templates.length ? templates : [
    { difficulty: "보통", prompt: "'{focus}'의 뜻을 설명하세요.", answer: "정의와 대표 예시를 함께 확인합니다." }
  ];

  return source.map((item, index) => {
    const focus = profile.focus[index % profile.focus.length] || subject;
    const base = {
      type: label,
      difficulty: item.difficulty,
      prompt: hydrateTemplate(item.prompt, { subject, focus, formula: profile.formula }),
      answer: hydrateTemplate(item.answer, { subject, focus, formula: profile.formula })
    };
    return formatQuestion(base, format, index);
  }).concat(formatQuestion({
    type: label,
    difficulty: "종합",
    prompt: `${subject} 핵심 개념 중 하나를 골라 정의, 예시, 주의할 점을 포함해 설명하세요.`,
    answer: "정의만 쓰지 말고 예시와 반례 또는 주의 조건을 함께 쓰면 답안의 완성도가 올라갑니다."
  }, format === "mixed" ? "short" : format, source.length));
}

function formatQuestion(question, format, index) {
  const mode = format === "mixed" ? ["multiple", "ox", "blank", "short"][index % 4] : format;
  if (mode === "multiple") {
    return {
      ...question,
      format: "객관식",
      prompt: `${question.prompt}\n\n① 정의만 암기한다 ② 핵심 조건과 예시를 함께 확인한다 ③ 해설을 보지 않는다 ④ 단원명을 외운다`,
      answer: `${question.answer} 정답은 ②에 가깝습니다.`
    };
  }
  if (mode === "ox") {
    return {
      ...question,
      format: "OX",
      prompt: `OX: ${question.prompt} 이 설명은 학습 개념과 연결해 판단할 수 있다.`,
      answer: `${question.answer} 핵심 근거가 있으면 O, 근거가 빠지면 X로 판단합니다.`
    };
  }
  if (mode === "blank") {
    return {
      ...question,
      format: "빈칸",
      prompt: question.prompt.replace(/'([^']+)'/, "'____'"),
      answer: question.answer
    };
  }
  return { ...question, format: "주관식" };
}

function formatLabel(format) {
  return {
    mixed: "혼합형",
    multiple: "객관식",
    ox: "OX",
    blank: "빈칸",
    short: "주관식"
  }[format] || format || "문제";
}

function hydrateTemplate(template, values) {
  return template
    .replaceAll("{subject}", values.subject)
    .replaceAll("{focus}", values.focus)
    .replaceAll("{formula}", values.formula);
}

function routineFor(subject) {
  if (subject.includes("수학") || ["미적분", "확률과 통계", "기하"].includes(subject)) {
    return ["정의 확인", "공식 유도", "대표 유형", "오답 조건", "시간 제한 풀이"];
  }
  if (["과학", "통합과학", "물리학", "화학", "생명과학", "지구과학"].includes(subject)) {
    return ["현상 관찰", "개념·법칙", "실험/자료", "단위·그래프", "적용 문제"];
  }
  if (subject.includes("영어")) {
    return ["어휘", "문장 구조", "문단 흐름", "선지 근거", "요약 작성"];
  }
  if (["국어", "공통국어", "문학", "독서", "화법과 작문", "언어와 매체"].includes(subject)) {
    return ["갈래/유형", "핵심 근거", "표현 방식", "보기 연결", "답안 문장화"];
  }
  if (["사회", "통합사회", "사회문화", "생활과 윤리", "윤리와 사상", "정치와 법", "경제", "한국사", "세계사", "동아시아사", "한국지리", "세계지리"].includes(subject)) {
    return ["개념 정의", "자료 해석", "사례 연결", "관점 비교", "쟁점 정리"];
  }
  return ["개념 이해", "예시 확인", "문제 적용", "오답 정리", "복습"];
}

function tipsFor(subject) {
  if (subject.includes("수학") || ["미적분", "확률과 통계", "기하"].includes(subject)) {
    return ["풀이 전에 조건을 기호로 정리하세요.", "공식은 암기보다 적용 조건을 먼저 확인하세요.", "틀린 문제는 계산 실수와 개념 실수를 분리하세요."];
  }
  if (["과학", "통합과학", "물리학", "화학", "생명과학", "지구과학"].includes(subject)) {
    return ["그래프의 축과 단위를 먼저 확인하세요.", "실험은 조작 변인과 종속 변인을 구분하세요.", "법칙은 적용 범위와 예외를 함께 정리하세요."];
  }
  if (subject.includes("영어") || subject === "제2외국어") {
    return ["모르는 단어보다 반복되는 핵심어를 먼저 표시하세요.", "연결어가 바뀌는 지점에서 글의 흐름을 확인하세요.", "선지는 지문 근거 문장과 직접 대조하세요."];
  }
  if (["국어", "공통국어", "문학", "독서", "화법과 작문", "언어와 매체"].includes(subject)) {
    return ["문제의 보기와 지문 근거를 1:1로 연결하세요.", "문학은 표현 효과와 정서를 함께 보세요.", "문법은 개념 정의와 예문 조건을 같이 외우세요."];
  }
  if (["사회", "통합사회", "사회문화", "생활과 윤리", "윤리와 사상", "정치와 법", "경제", "한국사", "세계사", "동아시아사", "한국지리", "세계지리", "역사"].includes(subject)) {
    return ["개념어를 사례와 함께 묶어 기억하세요.", "자료형 문제는 기준, 단위, 비교 대상을 먼저 보세요.", "윤리·사회 쟁점은 입장별 근거를 표로 정리하세요."];
  }
  return ["개념을 자기 말로 바꿔 설명하세요.", "예시와 반례를 함께 정리하세요.", "복습할 때는 틀린 이유를 한 줄로 남기세요."];
}

function examFocusFor(subject) {
  if (subject.includes("수학") || ["미적분", "확률과 통계", "기하"].includes(subject)) {
    return ["조건 해석", "대표 유형 변형", "계산 검산"];
  }
  if (["과학", "통합과학", "물리학", "화학", "생명과학", "지구과학"].includes(subject)) {
    return ["자료 해석", "실험 설계", "법칙 적용"];
  }
  if (subject.includes("영어") || subject === "제2외국어") {
    return ["주제·요지", "빈칸·삽입", "어법·어휘"];
  }
  if (["국어", "공통국어", "문학", "독서", "화법과 작문", "언어와 매체"].includes(subject)) {
    return ["근거 찾기", "표현 효과", "보기 적용"];
  }
  if (["사회", "통합사회", "사회문화", "생활과 윤리", "윤리와 사상", "정치와 법", "경제", "한국사", "세계사", "동아시아사", "한국지리", "세계지리", "역사"].includes(subject)) {
    return ["개념 비교", "자료·도표", "사례 판단"];
  }
  return ["개념 확인", "사례 적용", "서술형 표현"];
}

function renderAll() {
  renderSummary();
  renderTable();
  renderMindmap();
  renderQuestions();
  renderWorksheet();
}

function renderSummary() {
  const result = state.result;
  $("summaryTitle").textContent = result.title;
  $("summaryContent").innerHTML = `
    <article class="card large">
      <h3>${escapeHtml(result.unit)} 요약</h3>
      <p>${escapeHtml(result.summary)}</p>
    </article>
    <article class="card">
      <h3>학습목표</h3>
      <p>${escapeHtml(result.goal)}</p>
    </article>
    <article class="card">
      <h3>성취기준 메모</h3>
      <p>${escapeHtml(result.achievement)}</p>
    </article>
    <article class="card">
      <h3>교과서 기준</h3>
      <p>${escapeHtml(result.textbookNote)}</p>
    </article>
    <article class="card">
      <h3>교육과정</h3>
      <p>${escapeHtml(result.curriculum)}</p>
    </article>
    <article class="card">
      <h3>핵심 공식/전략</h3>
      <p>${escapeHtml(result.formula)}</p>
    </article>
    <article class="card full">
      <h3>추천 학습 루틴</h3>
      <div class="pill-row">${(result.routine || []).map((step) => `<span class="pill">${escapeHtml(step)}</span>`).join("")}</div>
    </article>
    <article class="card large">
      <h3>학습 팁</h3>
      <ul class="compact-list">${(result.tips || []).map((tip) => `<li>${escapeHtml(tip)}</li>`).join("")}</ul>
    </article>
    <article class="card">
      <h3>출제 포인트</h3>
      <div class="pill-row">${(result.examFocus || []).map((focus) => `<span class="pill">${escapeHtml(focus)}</span>`).join("")}</div>
    </article>
    <article class="card full">
      <h3>핵심 키워드</h3>
      <div class="pill-row">${result.keywords.map((word) => `<span class="pill">${escapeHtml(word)}</span>`).join("")}</div>
    </article>
    ${result.userText ? `<article class="card full"><h3>직접 입력 기반 메모</h3><p>${escapeHtml(result.userText)}</p></article>` : ""}
  `;
}

function renderTable() {
  $("conceptTable").innerHTML = state.result.table.map((row) => `
    <tr>
      <td>${escapeHtml(row.name)}</td>
      <td>${escapeHtml(row.content)}</td>
      <td>${escapeHtml(row.point)}</td>
    </tr>
  `).join("");
}

function renderMindmap() {
  $("mindmapCanvas").innerHTML = `
    <div class="mind-root">${escapeHtml(state.result.title)} · ${escapeHtml(state.result.unit)}</div>
    <div class="mind-branches">
      ${state.result.mindmap.map((node) => `
        <div class="mind-node">
          <strong>${escapeHtml(node.name)}</strong>
          <span>${escapeHtml(node.detail)}</span>
        </div>
      `).join("")}
    </div>
  `;
}

function renderQuestions() {
  $("questionTitle").textContent = `${state.result.subject} · ${state.result.questions[0]?.type || "문제"} · ${formatLabel(state.result.format || "mixed")}`;
  $("questionList").innerHTML = state.result.questions.map((q, index) => `
    <article class="question">
      <div class="meta">${escapeHtml(q.type)} · ${escapeHtml(q.format || "문제")} · ${escapeHtml(q.difficulty)}</div>
      <h3>${index + 1}. ${escapeHtml(q.prompt)}</h3>
      <div class="button-row">
        <button class="answer-toggle" data-answer-toggle type="button">해설 보기</button>
        <button class="answer-toggle" data-mistake-save="${index}" type="button">오답노트 저장</button>
      </div>
      <div class="answer" hidden><strong>정답/해설:</strong> ${escapeHtml(q.answer)}</div>
    </article>
  `).join("");
}

function renderWorksheet() {
  if (!state.result) return;
  $("worksheetTitle").textContent = `${state.result.title} 학습지`;
  $("worksheetContent").innerHTML = `
    <header class="worksheet-head">
      <p>koreastudy</p>
      <h1>${escapeHtml(state.result.title)}</h1>
      <div>${escapeHtml(state.result.curriculum)} · ${escapeHtml(state.result.unit)} · ${escapeHtml(state.result.textbookNote)}</div>
    </header>
    <section>
      <h2>1. 핵심 요약</h2>
      <p>${escapeHtml(state.result.summary)}</p>
    </section>
    <section>
      <h2>2. 학습목표와 성취기준 메모</h2>
      <p><strong>학습목표:</strong> ${escapeHtml(state.result.goal || "")}</p>
      <p><strong>성취기준 메모:</strong> ${escapeHtml(state.result.achievement || "")}</p>
    </section>
    <section>
      <h2>3. 핵심 키워드</h2>
      <ul>${state.result.keywords.map((word) => `<li>${escapeHtml(word)}</li>`).join("")}</ul>
    </section>
    <section>
      <h2>4. 학습 팁과 출제 포인트</h2>
      <ul>${(state.result.tips || []).map((tip) => `<li>${escapeHtml(tip)}</li>`).join("")}</ul>
      <p><strong>출제 포인트:</strong> ${(state.result.examFocus || []).map(escapeHtml).join(", ")}</p>
    </section>
    <section>
      <h2>5. 표 정리</h2>
      <table>
        <thead><tr><th>구분</th><th>내용</th><th>포인트</th></tr></thead>
        <tbody>
          ${state.result.table.map((row) => `<tr><td>${escapeHtml(row.name)}</td><td>${escapeHtml(row.content)}</td><td>${escapeHtml(row.point)}</td></tr>`).join("")}
        </tbody>
      </table>
    </section>
    <section>
      <h2>6. 확인 문제</h2>
      ${state.result.questions.map((q, index) => `
        <div class="worksheet-question">
          <strong>${index + 1}. [${escapeHtml(q.format || "문제")} · ${escapeHtml(q.difficulty)}] ${escapeHtml(q.prompt)}</strong>
          <p>정답/해설: ${escapeHtml(q.answer)}</p>
        </div>
      `).join("")}
    </section>
  `;
}

function toggleAnswer(event) {
  const button = event.target.closest("[data-answer-toggle]");
  if (!button) return;
  const answer = button.closest(".question").querySelector(".answer");
  const hidden = answer.hasAttribute("hidden");
  if (hidden) {
    answer.removeAttribute("hidden");
    button.textContent = "해설 숨기기";
  } else {
    answer.setAttribute("hidden", "");
    button.textContent = "해설 보기";
  }
}

function handleTextbook(event) {
  event.preventDefault();
  generateMaterial({
    publisher: $("publisher").value.trim(),
    author: $("author").value.trim(),
    unit: $("unit").value.trim(),
    userText: $("userText").value.trim()
  });
  switchView("summary");
}

function saveCurrent() {
  if (!state.result) return;
  const items = getLibrary();
  items.unshift({
    id: Date.now(),
    title: state.result.title,
    subject: state.result.subject,
    unit: state.result.unit,
    summary: state.result.summary,
    createdAt: new Date().toLocaleString("ko-KR")
  });
  localStorage.setItem("ks_library", JSON.stringify(items.slice(0, 40)));
  renderLibrary();
  switchView("library");
}

function handleMistakeSave(event) {
  const button = event.target.closest("[data-mistake-save]");
  if (!button || !state.result) return;
  const index = Number(button.dataset.mistakeSave);
  const question = state.result.questions[index];
  if (!question) return;
  const items = getMistakes();
  items.unshift({
    id: Date.now(),
    title: state.result.title,
    subject: state.result.subject,
    unit: state.result.unit,
    type: question.type,
    difficulty: question.difficulty,
    prompt: question.prompt,
    answer: question.answer,
    reviewCount: 0,
    lastReviewedAt: "",
    createdAt: new Date().toLocaleString("ko-KR")
  });
  localStorage.setItem("ks_mistakes", JSON.stringify(items.slice(0, 80)));
  renderMistakes();
  button.textContent = "저장됨";
}

function downloadCurrent() {
  if (!state.result) return;
  const lines = [
    `# ${state.result.title}`,
    "",
    `교육과정: ${state.result.curriculum || ""}`,
    `단원: ${state.result.unit}`,
    `교과서 기준: ${state.result.textbookNote}`,
    "",
    "## 요약",
    state.result.summary,
    "",
    "## 학습목표",
    state.result.goal || "",
    "",
    "## 성취기준 메모",
    state.result.achievement || "",
    "",
    "## 핵심 키워드",
    state.result.keywords.map((item) => `- ${item}`).join("\n"),
    "",
    "## 학습 팁",
    (state.result.tips || []).map((item) => `- ${item}`).join("\n"),
    "",
    "## 출제 포인트",
    (state.result.examFocus || []).map((item) => `- ${item}`).join("\n"),
    "",
    "## 표 정리",
    state.result.table.map((row) => `- ${row.name}: ${row.content} / ${row.point}`).join("\n"),
    "",
    "## 문제",
    state.result.questions.map((q, index) => `${index + 1}. [${q.type}/${q.format || "문제"}/${q.difficulty}] ${q.prompt}\n   해설: ${q.answer}`).join("\n")
  ];
  const blob = new Blob([lines.join("\n")], { type: "text/plain;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = `${state.result.subject}-${state.result.grade}학년-요약.txt`;
  link.click();
  URL.revokeObjectURL(url);
}

function getLibrary() {
  try {
    return JSON.parse(localStorage.getItem("ks_library") || "[]");
  } catch {
    return [];
  }
}

function getMistakes() {
  try {
    return JSON.parse(localStorage.getItem("ks_mistakes") || "[]");
  } catch {
    return [];
  }
}

function renderLibrary() {
  const items = getLibrary();
  $("libraryList").innerHTML = items.length
    ? items.map((item) => `
      <article class="library-item">
        <div>
          <strong>${escapeHtml(item.title)} · ${escapeHtml(item.unit)}</strong>
          <p>${escapeHtml(item.summary)}</p>
          <p>${escapeHtml(item.createdAt)}</p>
        </div>
      </article>
    `).join("")
    : `<p class="notice">아직 저장한 요약이 없습니다. 요약 화면에서 보관함 저장을 눌러보세요.</p>`;
}

function clearLibrary() {
  localStorage.removeItem("ks_library");
  renderLibrary();
}

function renderMistakes() {
  const items = getMistakes();
  $("mistakeList").innerHTML = items.length
    ? items.map((item) => `
      <article class="question">
        <div class="meta">${escapeHtml(item.subject)} · ${escapeHtml(item.unit)} · ${escapeHtml(item.difficulty)}</div>
        <h3>${escapeHtml(item.prompt)}</h3>
        <div class="answer"><strong>정답/해설:</strong> ${escapeHtml(item.answer)}</div>
        <p class="muted-line">저장: ${escapeHtml(item.createdAt)} · 복습 ${Number(item.reviewCount || 0)}회${item.lastReviewedAt ? ` · 최근 복습: ${escapeHtml(item.lastReviewedAt)}` : ""}</p>
        <div class="button-row">
          <button class="answer-toggle" data-mistake-review="${item.id}" type="button">복습 완료</button>
          <button class="answer-toggle danger-button" data-mistake-remove="${item.id}" type="button">삭제</button>
        </div>
      </article>
    `).join("")
    : `<p class="notice">아직 저장한 오답이 없습니다. 문제 화면에서 오답노트 저장을 눌러보세요.</p>`;
}

function handleMistakeAction(event) {
  const reviewButton = event.target.closest("[data-mistake-review]");
  const removeButton = event.target.closest("[data-mistake-remove]");
  if (!reviewButton && !removeButton) return;

  const items = getMistakes();
  if (reviewButton) {
    const id = Number(reviewButton.dataset.mistakeReview);
    const next = items.map((item) => item.id === id
      ? { ...item, reviewCount: Number(item.reviewCount || 0) + 1, lastReviewedAt: new Date().toLocaleString("ko-KR") }
      : item
    );
    localStorage.setItem("ks_mistakes", JSON.stringify(next));
  }
  if (removeButton) {
    const id = Number(removeButton.dataset.mistakeRemove);
    localStorage.setItem("ks_mistakes", JSON.stringify(items.filter((item) => item.id !== id)));
  }
  renderMistakes();
}

function clearMistakes() {
  localStorage.removeItem("ks_mistakes");
  renderMistakes();
}

function loadSettings() {
  $("apiKey").value = localStorage.getItem("ks_gemini_key") || "";
  $("modelName").value = localStorage.getItem("ks_gemini_model") || "gemini-3.1-flash-lite";
}

function saveSettings() {
  const key = $("apiKey").value.trim();
  if (key) localStorage.setItem("ks_gemini_key", key);
  localStorage.setItem("ks_gemini_model", $("modelName").value);
  alert("설정을 저장했습니다. 다음 생성부터 Gemini 요청을 시도합니다.");
}

function forgetSettings() {
  localStorage.removeItem("ks_gemini_key");
  $("apiKey").value = "";
}

function toggleTheme() {
  state.theme = state.theme === "dark" ? "light" : "dark";
  localStorage.setItem("ks_theme", state.theme);
  document.documentElement.dataset.theme = state.theme;
}

async function requestGemini(base) {
  const model = localStorage.getItem("ks_gemini_model") || "gemini-3.1-flash-lite";
  const prompt = [
    "너는 한국 초중고 교육과정 기반 학습 요약 도우미다.",
    "저작권 있는 교과서 원문을 재현하지 말고, 사용자가 준 범위와 공개 가능한 일반 개념 중심으로 요약한다.",
    "JSON만 반환한다. 키는 summary, keywords, table, mindmap, questions를 사용한다.",
    `대상: ${base.title}`,
    `교육과정: ${base.curriculum}`,
    `단원: ${base.unit}`,
    `과목: ${base.subject}`,
    `문제 카테고리: ${base.category}`,
    `문제 형식: ${base.format}`,
    `직접 입력: ${base.userText || "없음"}`
  ].join("\n");

  const serverResponse = await requestGeminiViaFunction(prompt, model);
  if (serverResponse) return serverResponse;

  const apiKey = localStorage.getItem("ks_gemini_key");
  if (!apiKey) return null;

  const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(apiKey)}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: { responseMimeType: "application/json" }
    })
  });

  if (!response.ok) throw new Error(`Gemini request failed: ${response.status}`);
  const data = await response.json();
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) throw new Error("Gemini response was empty");
  return JSON.parse(text);
}

async function requestGeminiViaFunction(prompt, model) {
  try {
    const response = await fetch("/.netlify/functions/gemini", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ prompt, model })
    });
    if (!response.ok) return null;
    return await response.json();
  } catch {
    return null;
  }
}

function mergeAiResult(base, ai) {
  return {
    ...base,
    summary: ai.summary || base.summary,
    goal: ai.goal || ai.learningGoal || base.goal,
    achievement: ai.achievement || ai.achievementNote || base.achievement,
    tips: Array.isArray(ai.tips) ? ai.tips.slice(0, 5) : base.tips,
    examFocus: Array.isArray(ai.examFocus) ? ai.examFocus.slice(0, 5) : base.examFocus,
    keywords: Array.isArray(ai.keywords) ? ai.keywords.slice(0, 10) : base.keywords,
    table: Array.isArray(ai.table) ? ai.table.map(normalizeTableRow) : base.table,
    mindmap: Array.isArray(ai.mindmap) ? ai.mindmap.map(normalizeMindNode) : base.mindmap,
    questions: Array.isArray(ai.questions) ? ai.questions.map(normalizeQuestion) : base.questions
  };
}

function normalizeTableRow(row) {
  return {
    name: row.name || row.구분 || "개념",
    content: row.content || row.핵심내용 || row.summary || "핵심 내용",
    point: row.point || row.학습포인트 || row.tip || "학습 포인트"
  };
}

function normalizeMindNode(node) {
  return {
    name: node.name || node.title || "개념",
    detail: node.detail || node.description || "세부 내용"
  };
}

function normalizeQuestion(q) {
  return {
    type: q.type || "AI 생성",
    format: q.format || "AI",
    difficulty: q.difficulty || "보통",
    prompt: q.prompt || q.question || "문제",
    answer: q.answer || q.explanation || "해설"
  };
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

init();
