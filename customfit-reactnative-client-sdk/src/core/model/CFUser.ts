import { CFUser, CFUserBuilder } from '../types/CFTypes';

/**
 * User model implementation for CustomFit SDK
 */
export class CFUserImpl implements CFUser {
  userCustomerId?: string;
  anonymousId?: string;
  deviceId?: string;
  anonymous?: boolean;
  properties?: Record<string, any>;

  constructor(
    userCustomerId?: string,
    anonymousId?: string,
    deviceId?: string,
    anonymous?: boolean,
    properties?: Record<string, any>
  ) {
    this.userCustomerId = userCustomerId;
    this.anonymousId = anonymousId;
    this.deviceId = deviceId;
    this.anonymous = anonymous ?? false;
    this.properties = properties ?? {};
  }

  /**
   * Create a new user with updated user customer ID
   */
  withUserCustomerId(userCustomerId: string): CFUser {
    return new CFUserImpl(
      userCustomerId,
      this.anonymousId,
      this.deviceId,
      this.anonymous,
      this.properties
    );
  }

  /**
   * Create a new user with updated anonymous ID
   */
  withAnonymousId(anonymousId: string): CFUser {
    return new CFUserImpl(
      this.userCustomerId,
      anonymousId,
      this.deviceId,
      this.anonymous,
      this.properties
    );
  }

  /**
   * Create a new user with updated device ID
   */
  withDeviceId(deviceId: string): CFUser {
    return new CFUserImpl(
      this.userCustomerId,
      this.anonymousId,
      deviceId,
      this.anonymous,
      this.properties
    );
  }

  /**
   * Create a new user with updated anonymous status
   */
  withAnonymous(anonymous: boolean): CFUser {
    return new CFUserImpl(
      this.userCustomerId,
      this.anonymousId,
      this.deviceId,
      anonymous,
      this.properties
    );
  }

  /**
   * Create a new user with updated properties
   */
  withProperties(properties: Record<string, any>): CFUser {
    return new CFUserImpl(
      this.userCustomerId,
      this.anonymousId,
      this.deviceId,
      this.anonymous,
      { ...this.properties, ...properties }
    );
  }

  /**
   * Create a new user with a single updated property
   */
  withProperty(key: string, value: any): CFUser {
    return this.withProperties({ [key]: value });
  }

  /**
   * Convert user to a plain object for API calls
   */
  toUserMap(): Record<string, any> {
    const map: Record<string, any> = {
      anonymous: this.anonymous ?? false,
      properties: {
        ...this.properties,
        device: {
          device_id: this.deviceId,
          os_name: 'React Native',
          sdk_type: 'react-native',
          sdk_version: '1.0.0',
        },
      },
    };

    if (this.userCustomerId) {
      map.user_customer_id = this.userCustomerId;
    }

    if (this.anonymousId) {
      map.anonymous_id = this.anonymousId;
    }

    return map;
  }

  /**
   * Create a default user instance
   */
  static defaultUser(): CFUser {
    return new CFUserImpl();
  }

  /**
   * Create a builder for constructing users
   */
  static builder(userCustomerId?: string): CFUserBuilder {
    return new CFUserBuilderImpl(userCustomerId);
  }
}

/**
 * Builder for creating CFUser instances
 */
export class CFUserBuilderImpl implements CFUserBuilder {
  private _userCustomerId?: string;
  private _anonymousId?: string;
  private _deviceId?: string;
  private _anonymous?: boolean;
  private _properties?: Record<string, any>;

  constructor(userCustomerId?: string) {
    this._userCustomerId = userCustomerId;
    this._properties = {};
  }

  userCustomerId(id: string): CFUserBuilder {
    this._userCustomerId = id;
    return this;
  }

  anonymousId(id: string): CFUserBuilder {
    this._anonymousId = id;
    return this;
  }

  deviceId(id: string): CFUserBuilder {
    this._deviceId = id;
    return this;
  }

  anonymous(isAnonymous: boolean): CFUserBuilder {
    this._anonymous = isAnonymous;
    return this;
  }

  properties(props: Record<string, any>): CFUserBuilder {
    this._properties = { ...this._properties, ...props };
    return this;
  }

  property(key: string, value: any): CFUserBuilder {
    if (!this._properties) {
      this._properties = {};
    }
    this._properties[key] = value;
    return this;
  }

  build(): CFUser {
    return new CFUserImpl(
      this._userCustomerId,
      this._anonymousId,
      this._deviceId,
      this._anonymous,
      this._properties
    );
  }
} 