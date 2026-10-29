const SYSTEM_PROMPT = `Sos el asistente virtual de REDMOOT, una inmobiliaria en Cali, Colombia. Respondé en español colombiano, con calidez y brevedad. Ayudá con la búsqueda, los barrios, las propiedades mostradas y cómo pedir citas. No inventes precios, disponibilidad, servicios, direcciones ni recorridos ya existentes. Si te preguntan por la cita a domicilio, explicá que pueden solicitarla desde el formulario y que el equipo debe confirmar disponibilidad; no prometas que el recorrido ya está disponible. Propiedades de ejemplo del catálogo actual: Luz de tarde, departamento en Granada, venta, 480.000.000 COP; Casa en calma, casa en Pance, venta, 1.250.000.000 COP; Aire de ciudad, departamento en San Fernando, alquiler, 3.200.000 COP mensuales; Patio propio, PH en El Peñón, venta, 680.000.000 COP. Para reservar, indicá usar el botón “Reservar cita”, elegir propiedad, tipo de visita, fecha y horario. No pidas datos personales dentro del chat. Si necesitás información que no tenés, recomendá escribir a hola@redmoot.com.co.`;

const requestWindow = new Map();

function withinRateLimit(key) {
  const now = Date.now();
  const prior = requestWindow.get(key);
  if (!prior || now - prior.startedAt >= 60_000) { requestWindow.set(key, { startedAt: now, count: 1 }); return true; }
  if (prior.count >= 20) return false;
  prior.count += 1;
  if (requestWindow.size > 1000) for (const [ip, entry] of requestWindow) if (now - entry.startedAt >= 60_000) requestWindow.delete(ip);
  return true;
}

module.exports = async function handler(req, res) {
  res.setHeader('Cache-Control', 'no-store');
  if (req.method !== 'POST') return res.status(405).json({ error: 'Método no permitido.' });
  const clientIp = String(req.headers['x-forwarded-for'] || 'unknown').split(',')[0].trim().slice(0, 80);
  if (!withinRateLimit(clientIp)) return res.status(429).json({ error: 'Llegaron muchas preguntas seguidas. Espera un minuto e intenta de nuevo.' });
  if (!process.env.OPENAI_API_KEY) return res.status(503).json({ error: 'El asistente IA aún no está conectado. El equipo puede ayudarte desde Contacto.' });
  const history = Array.isArray(req.body?.messages) ? req.body.messages.slice(-8) : [];
  if (!history.length || history.some(item => !['user', 'assistant'].includes(item.role) || typeof item.content !== 'string' || item.content.length > 600)) {
    return res.status(400).json({ error: 'La pregunta no tiene un formato válido.' });
  }
  try {
    const response = await fetch('https://api.openai.com/v1/responses', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: process.env.OPENAI_MODEL || 'gpt-6-luna', instructions: SYSTEM_PROMPT, input: history, max_output_tokens: 350, store: false })
    });
    const data = await response.json();
    if (!response.ok) return res.status(502).json({ error: 'No pudimos obtener una respuesta del asistente. Intenta de nuevo.' });
    const answer = (data.output || []).flatMap(item => item.content || []).filter(item => item.type === 'output_text').map(item => item.text).join('\n').trim();
    if (!answer) return res.status(502).json({ error: 'El asistente no pudo responder ahora. Intenta de nuevo.' });
    return res.status(200).json({ answer });
  } catch {
    return res.status(502).json({ error: 'No hay conexión con el asistente en este momento.' });
  }
};

