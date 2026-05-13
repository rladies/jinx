const CODING_PATTERNS = [
  /```/,
  /\b(library|install\.packages|require|source|setwd)\s*\(/i,
  /\bfunction\s*\(/,
  /<-/,
  /%>%/,
  /\|>/,
  /\bdata\.(frame|table)\s*\(/i,
  /\b(tidyverse|ggplot2?|dplyr|tibble|purrr|stringr|forcats|lubridate|tidyr|readr|broom|tidymodels|data\.table|magrittr|rlang|targets|renv|usethis|devtools|roxygen2|testthat|shiny|rmarkdown|quarto|knitr)\b/i,

  /\b(import|from)\s+[a-zA-Z_][\w.]*(\s+import\b)?/,
  /\b(def|lambda|class)\s+[a-zA-Z_]\w*\s*[:(]/,
  /\b(pandas|numpy|matplotlib|seaborn|scikit-learn|sklearn|tensorflow|pytorch|polars)\b/i,
  /\bdf\.(head|tail|loc|iloc|groupby|merge|join|drop|apply|map|astype)\b/i,

  /\bselect\b[\s\S]*\bfrom\b/i,
  /\b(inner|left|right|outer|cross)\s+join\b/i,

  /^\s*error[: ]/im,
  /\berror in\b/i,
  /^\s*warning[: ]/im,
  /\btraceback\b/i,
  /\bstack\s*trace\b/i,
  /\bsegmentation fault\b/i,
  /\bnullpointer/i,
  /\bnan\b.*\b(error|issue|problem)\b/i,

  /\bmy (code|script|function|model|regex|query|dataframe|tibble|notebook|chunk|pipeline|loop)\b/i,
  /\b(debug(ging)?|stack[- ]?trace|stacktrace)\b/i,
  /\bhow (do|can) i\b[\s\S]{0,40}\b(in|with|using)\s+(r|python|sql|stata|sas|julia|scala|spark|bash|shell)\b/i,
  /\bwrite (me )?(a |the )?(function|script|loop|regex|query|code|snippet)\b/i,
  /\b(fix|debug|optimi[sz]e|refactor) (my|this|the) (code|script|function|query|regex|model)\b/i,
  /\bcode (review|snippet|sample|example) (please|pls)?\b/i,

  /\b(p[- ]?value|regression|ANOVA|chi[- ]?square|t[- ]?test|odds ratio|confidence interval|standard error|coefficient|residuals?|heteroscedastic|multicollinearity)\b/i,
  /\b(fit (a|the) model|linear model|logistic regression|mixed[- ]?effects|random[- ]?effects|GLM|glmm|lmer|lm\(|glm\()\b/i,
];

export function is_coding_question(query) {
  if (!query || typeof query !== "string") return false;
  const trimmed = query.trim();
  if (!trimmed) return false;
  return CODING_PATTERNS.some((re) => re.test(trimmed));
}

export function coding_decline_message() {
  return (
    "🐈‍⬛ Oh — that one's outside my expertise. I'm a community familiar, not a coding " +
    "assistant (paws, no thumbs, very small brain for syntax). Pop your question into " +
    "*#help-r* — that's where folks who actually know their way around R hang out, and " +
    "they'll happily take a look. 💜"
  );
}
