import React from 'react';
import { CustomFitProvider } from './src/providers/CustomFitProvider';
import HomeScreen from './src/screens/HomeScreen';

const App: React.FC = () => {
  return (
    <CustomFitProvider>
      <HomeScreen />
    </CustomFitProvider>
  );
};

export default App; 