# 데이터 파일 분리 계획

현재 koreastudy는 무료 정적 배포와 빠른 로딩을 위해 `data/education-data.js` 단일 런타임 파일을 사용합니다.

데이터가 더 커지면 아래 기준으로 나눕니다.

## 분리 기준

- 앱 실행에 반드시 필요한 목록: `catalog.js`
- 국어 계열: `profiles-korean.js`
- 수학 계열: `profiles-math.js`
- 영어/외국어 계열: `profiles-english.js`
- 사회/역사 계열: `profiles-social.js`
- 과학 계열: `profiles-science.js`
- 예체능/생활/진로 계열: `profiles-life-arts.js`
- 문제 템플릿: `question-templates.js`
- 검증/저작권/업데이트 메타데이터: `governance.js`

## 지금 바로 완전 분리하지 않는 이유

- 빌드 도구 없이 바로 열리는 정적 앱을 유지하기 위해서입니다.
- 파일 수가 늘어나면 브라우저에서 직접 열 때 누락 가능성이 커집니다.
- Netlify 배포 전까지는 단일 파일이 운영 리스크가 낮습니다.

## 분리 시점

- 과목별 프로필이 100개 이상이 될 때
- 단원 시드가 500개 이상이 될 때
- 공식 교육과정 자료 대조가 끝나 과목별 출처 메타데이터를 별도 관리해야 할 때
- 관리자 편집 화면을 추가할 때

