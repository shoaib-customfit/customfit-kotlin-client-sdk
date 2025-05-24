import { EventData, EventType } from '../../core/types/CFTypes';
import { DeviceInfoUtil } from '../../platform/DeviceInfo';

/**
 * Event data builder and utilities
 */
export class EventDataBuilder {
  private name: string;
  private properties: Record<string, any> = {};
  private sessionId: string = '';
  private userId?: string;
  private anonymousId?: string;
  private deviceId?: string;

  constructor(name: string) {
    this.name = name;
    this.sessionId = EventDataBuilder.generateSessionId();
  }

  /**
   * Set event properties
   */
  setProperties(properties: Record<string, any>): EventDataBuilder {
    this.properties = { ...this.properties, ...properties };
    return this;
  }

  /**
   * Set a single property
   */
  setProperty(key: string, value: any): EventDataBuilder {
    this.properties[key] = value;
    return this;
  }

  /**
   * Set user customer ID
   */
  setUserId(userId: string): EventDataBuilder {
    this.userId = userId;
    return this;
  }

  /**
   * Set anonymous ID
   */
  setAnonymousId(anonymousId: string): EventDataBuilder {
    this.anonymousId = anonymousId;
    return this;
  }

  /**
   * Set device ID
   */
  setDeviceId(deviceId: string): EventDataBuilder {
    this.deviceId = deviceId;
    return this;
  }

  /**
   * Set session ID
   */
  setSessionId(sessionId: string): EventDataBuilder {
    this.sessionId = sessionId;
    return this;
  }

  /**
   * Build the event data
   */
  async build(): Promise<EventData> {
    // Get device info if device ID is not set
    if (!this.deviceId) {
      const deviceInfo = await DeviceInfoUtil.getDeviceInfo();
      this.deviceId = deviceInfo.deviceId;
    }

    const eventData: EventData = {
      id: EventDataBuilder.generateEventId(),
      name: this.name,
      eventType: EventType.TRACK,
      properties: { ...this.properties },
      timestamp: new Date().toISOString(),
      sessionId: this.sessionId,
      userId: this.userId,
      anonymousId: this.anonymousId,
      deviceId: this.deviceId,
    };

    return eventData;
  }

  /**
   * Generate a unique event ID
   */
  private static generateEventId(): string {
    return `evt_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * Generate a session ID (reused across events in the same session)
   */
  private static generateSessionId(): string {
    // In a real app, this would be more sophisticated and persist across app launches
    if (!EventDataBuilder.currentSessionId) {
      EventDataBuilder.currentSessionId = `sess_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    }
    return EventDataBuilder.currentSessionId;
  }

  private static currentSessionId: string | null = null;

  /**
   * Start a new session
   */
  static startNewSession(): string {
    EventDataBuilder.currentSessionId = `sess_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    return EventDataBuilder.currentSessionId;
  }

  /**
   * Get current session ID
   */
  static getCurrentSessionId(): string {
    if (!EventDataBuilder.currentSessionId) {
      EventDataBuilder.currentSessionId = EventDataBuilder.generateSessionId();
    }
    return EventDataBuilder.currentSessionId;
  }
}

/**
 * Event data utilities
 */
export class EventDataUtil {
  /**
   * Create a simple event
   */
  static async createEvent(
    name: string,
    properties?: Record<string, any>,
    userId?: string,
    anonymousId?: string
  ): Promise<EventData> {
    const builder = new EventDataBuilder(name);
    
    if (properties) {
      builder.setProperties(properties);
    }
    
    if (userId) {
      builder.setUserId(userId);
    }
    
    if (anonymousId) {
      builder.setAnonymousId(anonymousId);
    }

    return await builder.build();
  }



  /**
   * Validate event data
   */
  static validateEventData(eventData: EventData): boolean {
    if (!eventData.id || !eventData.name || !eventData.timestamp) {
      return false;
    }

    if (!eventData.sessionId) {
      return false;
    }

    // At least one of userId, anonymousId, or deviceId should be present
    if (!eventData.userId && !eventData.anonymousId && !eventData.deviceId) {
      return false;
    }

    return true;
  }

  /**
   * Serialize event data for API transmission
   */
  static serializeForAPI(eventData: EventData): Record<string, any> {
    const serialized: Record<string, any> = {
      id: eventData.id,
      name: eventData.name,
      event_type: eventData.eventType,
      timestamp: eventData.timestamp,
      session_id: eventData.sessionId,
      properties: eventData.properties || {},
    };

    if (eventData.userId) {
      serialized.user_customer_id = eventData.userId;
    }

    if (eventData.anonymousId) {
      serialized.anonymous_id = eventData.anonymousId;
    }

    if (eventData.deviceId) {
      serialized.device_id = eventData.deviceId;
    }

    return serialized;
  }

  /**
   * Deserialize event data from storage/API
   */
  static deserializeFromStorage(data: Record<string, any>): EventData | null {
    try {
      const eventData: EventData = {
        id: data.id,
        name: data.name,
        eventType: data.event_type || EventType.TRACK,
        timestamp: data.timestamp,
        sessionId: data.session_id || data.sessionId,
        properties: data.properties || {},
        userId: data.user_customer_id || data.userId,
        anonymousId: data.anonymous_id || data.anonymousId,
        deviceId: data.device_id || data.deviceId,
      };

      return EventDataUtil.validateEventData(eventData) ? eventData : null;
    } catch (error) {
      return null;
    }
  }
} 