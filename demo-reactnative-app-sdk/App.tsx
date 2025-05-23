/**
 * CustomFit React Native SDK Demo App
 * 
 * This app replicates the Flutter demo app functionality:
 * - Provider pattern for state management
 * - Multiple screens with navigation
 * - Real-time feature flag updates
 * - Event tracking with specific event names
 * - Offline mode toggle
 * - Configuration refresh functionality
 */

import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createStackNavigator } from '@react-navigation/stack';
import { CustomFitProvider } from './src/providers/CustomFitProvider';
import HomeScreen from './src/screens/HomeScreen';
import SecondScreen from './src/screens/SecondScreen';

const Stack = createStackNavigator();

const App: React.FC = () => {
  return (
    <CustomFitProvider>
      <NavigationContainer>
        <Stack.Navigator
          initialRouteName="HomeScreen"
          screenOptions={{
            headerShown: false, // We'll use custom headers in each screen
          }}>
          <Stack.Screen name="HomeScreen" component={HomeScreen} />
          <Stack.Screen name="SecondScreen" component={SecondScreen} />
        </Stack.Navigator>
      </NavigationContainer>
    </CustomFitProvider>
  );
};

export default App;
