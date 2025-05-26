import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  Alert,
  Switch,
  Dimensions,
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
        console.log('⚠️ Server loading timeout reached, showing UI with default values');
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
    // Use consistent event name pattern matching Android reference
    await customFit.trackEvent('react_native_toast_button_interaction', {
      action: 'click',
      feature: 'toast_message',
      platform: 'react_native'
    });

    // Create a toast-like alert that auto-dismisses
    const toastMessage = customFit.enhancedToast
      ? 'Enhanced toast feature enabled!'
      : 'Button clicked!';
    
    console.log(`🍞 Toast: ${toastMessage}`);
    
    // Show alert that mimics SnackBar behavior
    Alert.alert(
      'Toast',
      toastMessage,
      [{ text: 'OK' }],
      { cancelable: true }
    );
    
    // Also log to console for demo purposes
    console.log(`🚩 enhanced_toast flag is: ${customFit.enhancedToast}`);
  };

  const handleNavigateToSecond = async () => {
    // Use consistent event name pattern matching Android reference
    await customFit.trackEvent('react_native_screen_navigation', {
      from: 'main_screen',
      to: 'second_screen',
      user_flow: 'primary_navigation',
      platform: 'react_native'
    });

    navigation.navigate('Second' as never);
  };

  const handleRefreshConfig = async () => {
    if (isRefreshing) return;

    setIsRefreshing(true);
    console.log('🔄 Starting manual refresh...');

    try {
      // Use consistent event name pattern matching Android reference
      const success = await customFit.refreshFeatureFlags('react_native_config_manual_refresh');

      if (success) {
        console.log('✅ Refresh completed successfully');
        
        // Show success alert briefly
        Alert.alert(
          'Configuration Updated',
          'Feature flags have been refreshed from server!',
          [{ text: 'OK' }],
          { cancelable: true }
        );
      } else {
        console.log('⚠️ Refresh failed');
        Alert.alert(
          'Refresh Failed',
          'Could not update configuration. Please try again.',
          [{ text: 'OK' }],
          { cancelable: true }
        );
      }
    } catch (error) {
      console.error('❌ Refresh error:', error);
      Alert.alert(
        'Error',
        'An error occurred while refreshing configuration.',
        [{ text: 'OK' }],
        { cancelable: true }
      );
    } finally {
      setIsRefreshing(false);
    }
  };

    if (!customFit.isInitialized && !forceShowUI) {
    return (
      <View style={[styles.loadingContainer, { backgroundColor: '#f5f5f5', minHeight: Dimensions.get('window').height }]}>
        <ActivityIndicator size="large" color="#6200EE" />
        <Text style={[styles.loadingText, { color: '#333', fontSize: 18, marginTop: 16 }]}>
          Loading CustomFit from server...
        </Text>
        <Text style={[styles.loadingSubText, { color: '#666', fontSize: 14, marginTop: 8 }]}>
          Fetching feature flags and configuration
        </Text>
        <TouchableOpacity
          style={[styles.forceShowButton, { backgroundColor: '#6200EE', padding: 12, borderRadius: 8, marginTop: 16 }]}
          onPress={() => setForceShowUI(true)}>
          <Text style={[styles.forceShowButtonText, { color: 'white', fontSize: 16 }]}>Show UI anyway</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <View style={[styles.container, { minHeight: Dimensions.get('window').height }]}>
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
  loadingSubText: {
    marginTop: 8,
    fontSize: 14,
    color: '#666666',
    textAlign: 'center',
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