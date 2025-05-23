import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  Alert,
  Switch,
} from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { useCustomFit } from '../providers/CustomFitProvider';

const HomeScreen: React.FC = () => {
  const navigation = useNavigation();
  const customFit = useCustomFit();
  const [previousMessage, setPreviousMessage] = useState<string | null>(null);
  const [forceShowUI, setForceShowUI] = useState(false);
  const [isRefreshing, setIsRefreshing] = useState(false);

  useEffect(() => {
    // Add a safety timeout - if loading takes more than 10 seconds, show UI anyway
    const timeout = setTimeout(() => {
      if (!forceShowUI) {
        setForceShowUI(true);
        console.log('⚠️ Timeout reached, forcing UI to show');
      }
    }, 10000);

    return () => clearTimeout(timeout);
  }, [forceShowUI]);

  useEffect(() => {
    // Check for config changes and show notifications
    if (customFit.isInitialized &&
        customFit.hasNewConfigMessage &&
        customFit.lastConfigChangeMessage !== previousMessage) {
      
      setPreviousMessage(customFit.lastConfigChangeMessage);
      
      // Show alert for config changes (React Native equivalent of SnackBar)
      if (customFit.lastConfigChangeMessage) {
        Alert.alert(
          'Configuration Updated',
          customFit.lastConfigChangeMessage,
          [{ text: 'OK' }],
          { cancelable: true }
        );
      }
    }
  }, [customFit.isInitialized, customFit.hasNewConfigMessage, customFit.lastConfigChangeMessage, previousMessage]);

  const handleShowToast = async () => {
    // Use more specific event name and properties with react_native prefix
    await customFit.trackEvent('reactnative_toast_button_interaction', {
      action: 'click',
      feature: 'toast_message',
      platform: 'react_native'
    });

    Alert.alert(
      'Toast Message',
      customFit.enhancedToast
        ? 'Enhanced toast feature enabled!'
        : 'Button clicked!',
      [{ text: 'OK' }],
      { cancelable: true }
    );
  };

  const handleNavigateToSecond = async () => {
    // Use more specific event name and properties with react_native prefix
    await customFit.trackEvent('reactnative_screen_navigation', {
      from: 'main_screen',
      to: 'second_screen',
      user_flow: 'primary_navigation',
      platform: 'react_native'
    });

    navigation.navigate('SecondScreen' as never);
  };

  const handleRefreshConfig = async () => {
    if (isRefreshing) return;

    setIsRefreshing(true);

    // Show loading alert
    Alert.alert(
      'Refreshing Configuration',
      'Please wait...',
      [],
      { cancelable: false }
    );

    // Call the refresh method with react_native prefix
    await customFit.refreshFeatureFlags('reactnative_config_manual_refresh');

    setIsRefreshing(false);

    // Dismiss the loading alert and show success
    setTimeout(() => {
      Alert.alert(
        'Configuration Refreshed',
        'Configuration has been updated successfully!',
        [{ text: 'OK' }],
        { cancelable: true }
      );
    }, 100);
  };

  if (!customFit.isInitialized && !forceShowUI) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#6200EE" />
        <Text style={styles.loadingText}>Loading CustomFit...</Text>
        <TouchableOpacity
          style={styles.forceShowButton}
          onPress={() => setForceShowUI(true)}>
          <Text style={styles.forceShowButtonText}>Show UI anyway</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* Header with title and offline toggle */}
      <View style={styles.header}>
        <Text style={styles.title}>{customFit.heroText}</Text>
        <View style={styles.switchContainer}>
          <Text style={styles.switchLabel}>
            {customFit.isOffline ? 'Offline' : 'Online'}
          </Text>
          <Switch
            value={customFit.isOffline}
            onValueChange={customFit.toggleOfflineMode}
            trackColor={{ false: '#4CAF50', true: '#F44336' }}
            thumbColor={customFit.isOffline ? '#FFFFFF' : '#FFFFFF'}
          />
        </View>
      </View>

      {/* Main content */}
      <View style={styles.content}>
        <TouchableOpacity
          style={styles.button}
          onPress={handleShowToast}>
          <Text style={styles.buttonText}>Show Toast</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.button}
          onPress={handleNavigateToSecond}>
          <Text style={styles.buttonText}>Go to Second Screen</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[
            styles.button,
            styles.refreshButton,
            isRefreshing && styles.disabledButton
          ]}
          onPress={handleRefreshConfig}
          disabled={isRefreshing}>
          <View style={styles.refreshButtonContent}>
            {isRefreshing && (
              <ActivityIndicator
                size="small"
                color="#FFFFFF"
                style={styles.refreshSpinner}
              />
            )}
            <Text style={styles.buttonText}>
              {isRefreshing ? 'Refreshing Config...' : 'Refresh Config'}
            </Text>
          </View>
        </TouchableOpacity>

        {/* Feature flags display */}
        <View style={styles.flagsContainer}>
          <Text style={styles.flagsTitle}>Current Feature Flags:</Text>
          <Text style={styles.flagText}>
            hero_text: {customFit.heroText}
          </Text>
          <Text style={styles.flagText}>
            enhanced_toast: {customFit.enhancedToast ? 'true' : 'false'}
          </Text>
        </View>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#FFFFFF',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
  },
  loadingText: {
    marginTop: 16,
    fontSize: 18,
    color: '#333333',
  },
  forceShowButton: {
    marginTop: 16,
    paddingHorizontal: 16,
    paddingVertical: 8,
  },
  forceShowButtonText: {
    color: '#6200EE',
    fontSize: 16,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
    backgroundColor: '#6200EE',
  },
  title: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#FFFFFF',
    flex: 1,
  },
  switchContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  switchLabel: {
    color: '#FFFFFF',
    marginRight: 8,
    fontSize: 14,
  },
  content: {
    flex: 1,
    padding: 16,
  },
  button: {
    backgroundColor: '#6200EE',
    paddingVertical: 12,
    paddingHorizontal: 24,
    borderRadius: 8,
    marginBottom: 16,
    alignItems: 'center',
  },
  refreshButton: {
    backgroundColor: '#2196F3',
  },
  disabledButton: {
    backgroundColor: '#CCCCCC',
  },
  buttonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
  },
  refreshButtonContent: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  refreshSpinner: {
    marginRight: 8,
  },
  flagsContainer: {
    marginTop: 24,
    padding: 16,
    backgroundColor: '#F5F5F5',
    borderRadius: 8,
  },
  flagsTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    marginBottom: 8,
    color: '#333333',
  },
  flagText: {
    fontSize: 14,
    color: '#666666',
    marginBottom: 4,
  },
});

export default HomeScreen; 