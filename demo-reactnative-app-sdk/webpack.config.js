const path = require('path');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const webpack = require('webpack');

module.exports = {
  entry: path.resolve(__dirname, 'index.web.js'),
  mode: 'development',
  module: {
    rules: [
      {
        test: /\.(js|jsx|ts|tsx)$/,
        include: [
          path.resolve(__dirname, 'src'),
          path.resolve(__dirname, 'App.tsx'),
          path.resolve(__dirname, 'index.web.js'),
          path.resolve(__dirname, '../customfit-reactnative-client-sdk'),
          path.resolve(__dirname, 'node_modules/@customfit'),
          path.resolve(__dirname, 'node_modules/@react-native-community'),
          path.resolve(__dirname, 'node_modules/@react-native-async-storage'),
          path.resolve(__dirname, '../customfit-reactnative-client-sdk/node_modules/@react-native-community'),
          path.resolve(__dirname, '../customfit-reactnative-client-sdk/node_modules/@react-native-async-storage'),
        ],
        use: {
          loader: 'babel-loader',
          options: {
            presets: [
              'module:@react-native/babel-preset',
              '@babel/preset-typescript',
            ],
            plugins: [
              ['module-resolver', {
                alias: {
                  '^react-native$': 'react-native-web',
                },
              }],
            ],
          },
        },
      },
      {
        test: /\.(png|jpe?g|gif|svg)$/,
        use: {
          loader: 'file-loader',
          options: {
            name: '[name].[ext]',
            outputPath: 'assets/images/',
          },
        },
      },
    ],
  },
  resolve: {
    alias: {
      'react-native$': 'react-native-web',
      'react-native-web$': 'react-native-web',
      '@react-native-async-storage/async-storage': path.resolve(__dirname, './src/polyfills/async-storage.js'),
      '@react-native-community/netinfo': path.resolve(__dirname, './src/polyfills/netinfo.js'),
    },
    extensions: ['.web.js', '.web.ts', '.web.tsx', '.js', '.ts', '.tsx', '.json'],
    fallback: {
      "crypto": false,
      "stream": false,
      "buffer": false,
    },
    modules: [
      'node_modules',
      path.resolve(__dirname, 'node_modules'),
      path.resolve(__dirname, '../customfit-reactnative-client-sdk/node_modules'),
    ],
  },
  output: {
    path: path.resolve(__dirname, 'web-build'),
    filename: 'bundle.js',
    publicPath: '/',
  },
  plugins: [
    new HtmlWebpackPlugin({
      template: path.resolve(__dirname, 'public/index.html'),
      inject: 'body',
    }),
    // Replace react-native imports with react-native-web
    new webpack.NormalModuleReplacementPlugin(
      /^react-native$/,
      'react-native-web'
    ),
    new webpack.NormalModuleReplacementPlugin(
      /^react-native\/(.*)$/,
      (resource) => {
        resource.request = resource.request.replace(/^react-native\//, 'react-native-web/dist/');
      }
    ),
  ],
  devServer: {
    port: 3000,
    hot: true,
    open: true,
    historyApiFallback: true,
    // Use setupMiddlewares for custom request handling
    setupMiddlewares: (middlewares, devServer) => {
      if (!devServer) {
        throw new Error('webpack-dev-server is not defined');
      }

      // Add CORS headers for all requests
      devServer.app.use((req, res, next) => {
        res.header('Access-Control-Allow-Origin', '*');
        res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS, HEAD');
        res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization, If-Modified-Since, If-None-Match, ETag, Last-Modified');
        res.header('Access-Control-Allow-Credentials', 'true');
        
        if (req.method === 'OPTIONS') {
          res.sendStatus(200);
        } else {
          next();
        }
      });

      return middlewares;
    }
  },
}; 