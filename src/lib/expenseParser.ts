export type ParsedExpense = {
  amount: number | null;
  description: string;
  categoryId: string | null;
  categoryName: string | null;
  transactionType: 'expense' | 'income' | 'loan_given' | 'loan_received' | 'saving';
  person: string | null;
  confidence: number; // 0-100
};

// Keyword map: { categoryId -> keywords[] }
const CATEGORY_KEYWORDS: Record<string, string[]> = {
  'cat-alimentacion': [
    'pizza', 'comida', 'comer', 'almuerzo', 'cena', 'desayuno', 'restaurante', 'resto',
    'burger', 'hamburguesa', 'sushi', 'empanada', 'pizza', 'helado', 'postre', 'delivery',
    'pedidosya', 'rappi', 'merienda', 'snack',
  ],
  'cat-cafe': [
    'cafe', 'café', 'cafetería', 'cafeteria', 'starbucks', 'bar', 'cerveza', 'trago',
    'birra', 'copa', 'aperitivo', 'fernet', 'cortado', 'medialunas',
  ],
  'cat-supermercado': [
    'supermercado', 'super', 'almacen', 'almacén', 'verduleria', 'carnicería', 'carniceria',
    'feria', 'mercado', 'compras', 'coto', 'dia', 'jumbo', 'disco', 'walmart',
  ],
  'cat-transporte': [
    'taxi', 'uber', 'remis', 'cabify', 'subte', 'colectivo', 'micro', 'tren', 'peaje',
    'nafta', 'combustible', 'gasoil', 'estacion', 'estación', 'sube', 'boleto',
    'auto', 'parking', 'estacionamiento',
  ],
  'cat-entretenimiento': [
    'cine', 'teatro', 'concierto', 'recital', 'show', 'streaming', 'netflix', 'spotify',
    'disney', 'hbo', 'amazon', 'juego', 'videojuego', 'salida', 'boliche', 'club',
    'entrada', 'museo', 'parque',
  ],
  'cat-salud': [
    'farmacia', 'medicamento', 'medicina', 'doctor', 'médico', 'medico', 'dentista',
    'turno', 'consulta', 'analisis', 'análisis', 'obra social', 'prepaga', 'hospital',
    'clinica', 'clínica', 'osde', 'swiss medical',
  ],
  'cat-educacion': [
    'curso', 'libro', 'libros', 'universidad', 'facultad', 'escuela', 'colegio',
    'clases', 'cuota', 'matrícula', 'matricula', 'udemy', 'platzi', 'educacion',
  ],
  'cat-hogar': [
    'alquiler', 'expensas', 'luz', 'gas', 'agua', 'internet', 'telefono', 'cable',
    'limpieza', 'ferretería', 'ferreteria', 'mueble', 'electrodoméstico', 'arreglo',
    'plomero', 'electricista',
  ],
  'cat-servicios': [
    'personal cell', 'celular', 'internet', 'movistar', 'claro', 'personal', 'telecom',
    'servicio', 'suscripcion', 'suscripción',
  ],
  'cat-ropa': [
    'ropa', 'zapatillas', 'zapatos', 'remera', 'pantalon', 'pantalón', 'vestido',
    'calzado', 'chomba', 'campera', 'zara', 'h&m',
  ],
  'cat-tecnologia': [
    'tecnología', 'tecnologia', 'celular', 'computadora', 'laptop', 'tablet', 'iphone',
    'samsung', 'auriculares', 'accesorio', 'carga', 'cable',
  ],
  'cat-sueldo': [
    'sueldo', 'salario', 'cobré', 'cobre', 'pago', 'ingreso', 'honorarios',
  ],
  'cat-freelance': [
    'freelance', 'proyecto', 'trabajo', 'factura', 'cliente',
  ],
};

const CATEGORY_NAMES: Record<string, string> = {
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
};

const INCOME_KEYWORDS = ['cobré', 'cobre', 'cobrar', 'ingresé', 'ingrese', 'me pagaron', 'sueldo', 'salario', 'honorarios', 'factura cobrada'];
const LOAN_GIVEN_KEYWORDS = ['presté', 'preste', 'le presté', 'le di plata', 'le di $'];
const LOAN_RECEIVED_KEYWORDS = ['me prestaron', 'me prestó', 'me presto', 'pedí prestado'];
const SAVING_KEYWORDS = ['ahorro', 'ahorré', 'ahorre', 'guardé', 'guarde'];

function extractAmount(text: string): number | null {
  // Patterns: $500, $1.500, 500 pesos, 1500, 1,500.00
  const patterns = [
    /\$\s?(\d[\d.,]*)/,         // $500 or $1.500
    /(\d[\d.,]*)\s*pesos?/i,    // 500 pesos
    /(\d[\d.,]*)\s*(?:ars)?/i,  // standalone number
  ];
  for (const pattern of patterns) {
    const match = text.match(pattern);
    if (match) {
      const raw = match[1].replace(/\./g, '').replace(',', '.');
      const num = parseFloat(raw);
      if (!isNaN(num) && num > 0) return num;
    }
  }
  return null;
}

function extractPerson(text: string): string | null {
  // "con Juan", "a Juan", "le presté a Juan"
  const patterns = [
    /(?:con|a|para|de)\s+([A-ZÁÉÍÓÚÑ][a-záéíóúñ]+(?:\s+[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+)?)/,
  ];
  for (const pattern of patterns) {
    const match = text.match(pattern);
    if (match) return match[1];
  }
  return null;
}

function detectTransactionType(text: string): ParsedExpense['transactionType'] {
  const lower = text.toLowerCase();
  if (LOAN_GIVEN_KEYWORDS.some((k) => lower.includes(k))) return 'loan_given';
  if (LOAN_RECEIVED_KEYWORDS.some((k) => lower.includes(k))) return 'loan_received';
  if (INCOME_KEYWORDS.some((k) => lower.includes(k))) return 'income';
  if (SAVING_KEYWORDS.some((k) => lower.includes(k))) return 'saving';
  return 'expense';
}

function detectCategory(text: string): { categoryId: string | null; categoryName: string | null; matchCount: number } {
  const lower = text.toLowerCase();
  let bestCat: string | null = null;
  let bestCount = 0;

  for (const [catId, keywords] of Object.entries(CATEGORY_KEYWORDS)) {
    const count = keywords.filter((kw) => lower.includes(kw)).length;
    if (count > bestCount) {
      bestCount = count;
      bestCat = catId;
    }
  }

  return {
    categoryId: bestCat,
    categoryName: bestCat ? CATEGORY_NAMES[bestCat] ?? null : null,
    matchCount: bestCount,
  };
}

function cleanDescription(text: string, amount: number | null): string {
  let clean = text;
  if (amount !== null) {
    clean = clean.replace(/\$\s?\d[\d.,]*/g, '');
    clean = clean.replace(/\d[\d.,]*\s*pesos?/gi, '');
  }
  // Remove common filler words
  clean = clean.replace(/\b(gasté|gaste|gastei|pague|pagué|compré|compre|fui a|en|de|el|la|los|las|un|una|unos|unas)\b/gi, ' ');
  clean = clean.replace(/\s+/g, ' ').trim();
  return clean || text.trim();
}

export function parseExpenseText(text: string): ParsedExpense {
  const amount = extractAmount(text);
  const transactionType = detectTransactionType(text);
  const { categoryId, categoryName, matchCount } = detectCategory(text);
  const person = extractPerson(text);
  const description = cleanDescription(text, amount);

  // Confidence calculation
  let confidence = 0;
  if (amount !== null) confidence += 50;
  if (matchCount > 0) confidence += 30 + Math.min(matchCount * 5, 20);
  else if (description.length > 3) confidence += 10;

  return {
    amount,
    description,
    categoryId,
    categoryName,
    transactionType,
    person,
    confidence,
  };
}
