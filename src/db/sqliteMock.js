// Mock de expo-sqlite para web - devuelve datos vacíos sin crashear
const mockDb = {
  execSync: () => {},
  runSync: () => ({ lastInsertRowId: 0, changes: 0 }),
  getAllSync: () => [],
  getFirstSync: () => null,
};

module.exports = {
  openDatabaseSync: () => mockDb,
};
