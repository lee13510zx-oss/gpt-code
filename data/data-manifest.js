window.KS_DATA_MANIFEST = {
  version: "0.2.0",
  mode: "single-file-runtime",
  currentRuntimeFile: "data/education-data.js",
  splitPlan: [
    {
      file: "data/catalog.js",
      purpose: "학교급, 학년, 과목 목록"
    },
    {
      file: "data/profiles-korean.js",
      purpose: "국어, 문학, 독서, 화법과 작문, 언어와 매체"
    },
    {
      file: "data/profiles-math.js",
      purpose: "수학, 공통수학, 수학Ⅰ, 수학Ⅱ, 미적분, 확률과 통계, 기하"
    },
    {
      file: "data/profiles-english.js",
      purpose: "영어, 공통영어, 영어Ⅰ, 영어Ⅱ, 제2외국어"
    },
    {
      file: "data/profiles-social.js",
      purpose: "사회, 역사, 한국사, 통합사회, 사회 선택과목"
    },
    {
      file: "data/profiles-science.js",
      purpose: "과학, 통합과학, 물리학, 화학, 생명과학, 지구과학"
    },
    {
      file: "data/profiles-life-arts.js",
      purpose: "도덕, 음악, 미술, 체육, 실과, 기술가정, 진로와 직업"
    },
    {
      file: "data/question-templates.js",
      purpose: "문제 유형별 템플릿"
    },
    {
      file: "data/governance.js",
      purpose: "데이터 검증 상태와 저작권 정책"
    }
  ],
  migrationRule: "Netlify 배포 전까지는 요청 수를 줄이기 위해 단일 런타임 파일을 유지하고, 데이터가 더 커지면 위 계획대로 분리합니다."
};
