exports.handler = async (event) => {
  if (event.httpMethod !== "POST") {
    return json(405, { error: "Method not allowed" });
  }

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    return json(404, { error: "Gemini API key is not configured" });
  }

  let body;
  try {
    body = JSON.parse(event.body || "{}");
  } catch {
    return json(400, { error: "Invalid JSON body" });
  }

  const model = body.model || "gemini-3.1-flash-lite";
  const prompt = body.prompt;
  if (!prompt) {
    return json(400, { error: "Missing prompt" });
  }

  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent?key=${encodeURIComponent(apiKey)}`;
  const response = await fetch(endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: { responseMimeType: "application/json" }
    })
  });

  if (!response.ok) {
    return json(response.status, { error: "Gemini request failed" });
  }

  const data = await response.json();
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) {
    return json(502, { error: "Gemini response was empty" });
  }

  try {
    return json(200, JSON.parse(text));
  } catch {
    return json(502, { error: "Gemini response was not valid JSON" });
  }
};

function json(statusCode, payload) {
  return {
    statusCode,
    headers: { "Content-Type": "application/json; charset=utf-8" },
    body: JSON.stringify(payload)
  };
}
