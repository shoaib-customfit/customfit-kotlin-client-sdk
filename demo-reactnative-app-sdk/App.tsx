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
        <Stack.Navigator initialRouteName="Home">
          <Stack.Screen 
            name="Home" 
            component={HomeScreen} 
            options={{ title: 'CustomFit Demo' }}
          />
          <Stack.Screen 
            name="Second" 
            component={SecondScreen} 
            options={{ title: 'Second Screen' }}
          />
        </Stack.Navigator>
      </NavigationContainer>
    </CustomFitProvider>
  );
};

export default App; 