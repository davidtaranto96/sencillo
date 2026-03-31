import { ParsedExpense } from '@/src/lib/expenseParser';

const ANTHROPIC_API_KEY = process.env.EXPO_PUBLIC_ANTHROPIC_API_KEY ?? '';

const CATEGORY_IDS = [
  'cat-alimentacion', 'cat-cafe', 'cat-supermercado', 'cat-transporte',
  'cat-entretenimiento', 'cat-salud', 'cat-educacion', 'cat-hogar',
  'cat-servicios', 'cat-ropa', 'cat-tecnologia', 'cat-sueldo',
  'cat-freelance', 'cat-otros-gasto', 'cat-otros-ingreso',
];

const CATEGORY_MAP: Record<string, string> = {
  'cat-alimentacion': 'Alimentación',
  'cat-cafe': 'Café y bares',
  'cat-supermercado': 'Supermercado',
  'cat-transporte': 'Transporte',
  'cat-entretenimiento': 'Entretenimiento',
  'cat-salud': 'Salud',
  'cat-educacion': 'Educación',
  'cat-hogar': 'Hogar',
  'cat-servicios': 'Servicios',
  'cat-ropa': 'Ropa',
  'cat-tecnologia': 'Tecnología',
  'cat-sueldo': 'Sueldo',
  'cat-freelance': 'Freelance',
  'cat-otros-gasto': 'Otros gastos',
  'cat-otros-ingreso': 'Otros ingresos',
};

export async function classifyWithAI(text: string): Promise<ParsedExpense | null> {
  if (!ANTHROPIC_API_KEY) return null;

  const prompt = `Analizá este texto de gasto/ingreso en español argentino y devolvé un JSON con los campos indicados.

Texto: "${text}"

Categorías disponibles (usá solo el id): ${CATEGORY_IDS.join(', ')}

Tipos de transacción disponibles: expense, income, loan_given (le presté plata a alguien), loan_received (me prestaron plata), saving (ahorro)

Devolvé SOLO el JSON, sin texto extra:
{
  "amount": número o null,
  "description": "descripción corta en español",
  "categoryId": "id de categoría o null",
  "categoryName": "nombre de categoría o null",
  "transactionType": "expense | income | loan_given | loan_received | saving",
  "person": "nombre de persona mencionada o null"
}`;

  try {
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 256,
        messages: [{ role: 'user', content: prompt }],
      }),
    });

    if (!response.ok) return null;

    const data = await response.json();
    const content = data.content?.[0]?.text ?? '';
    const jsonMatch = content.match(/\{[\s\S]*\}/);
    if (!jsonMatch) return null;

    const parsed = JSON.parse(jsonMatch[0]);
    return {
      amount: typeof parsed.amount === 'number' ? parsed.amount : null,
      description: parsed.description ?? '',
      categoryId: CATEGORY_IDS.includes(parsed.categoryId) ? parsed.categoryId : null,
      categoryName: parsed.categoryName ?? (parsed.categoryId ? CATEGORY_MAP[parsed.categoryId] : null),
      transactionType: parsed.transactionType ?? 'expense',
      person: parsed.person ?? null,
      confidence: 90,
    };
  } catch {
    return null;
  }
}
