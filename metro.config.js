const { getDefaultConfig } = require('expo/metro-config');

const config = getDefaultConfig(__dirname);

// Para web: mock de expo-sqlite que devuelve datos vacíos
config.resolver.resolveRequest = (context, moduleName, platform) => {
  if (platform === 'web' && moduleName === 'expo-sqlite') {
    return {
      filePath: require.resolve('./src/db/sqliteMock.js'),
      type: 'sourceFile',
    };
  }
  return context.resolveRequest(context, moduleName, platform);
};

module.exports = config;
