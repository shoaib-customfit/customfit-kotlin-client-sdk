import { SummaryData } from '../../core/types/CFTypes';

/**
 * Summary data utilities for aggregating usage data
 */
export class SummaryDataUtil {
  /**
   * Create summary data
   */
  static createSummary(
    name: string,
    count: number = 1,
    properties?: Record<string, any>
  ): SummaryData {
    return {
      name,
      count,
      properties: properties || {},
    };
  }

  /**
   * Merge two summary data entries with the same name
   */
  static mergeSummaries(summary1: SummaryData, summary2: SummaryData): SummaryData {
    if (summary1.name !== summary2.name) {
      throw new Error('Cannot merge summaries with different names');
    }

    return {
      name: summary1.name,
      count: summary1.count + summary2.count,
      properties: { ...summary1.properties, ...summary2.properties },
    };
  }

  /**
   * Validate summary data
   */
  static validateSummaryData(summaryData: SummaryData): boolean {
    if (!summaryData.name) {
      return false;
    }

    if (typeof summaryData.count !== 'number' || summaryData.count < 0) {
      return false;
    }

    return true;
  }

  /**
   * Serialize summary data for API transmission
   */
  static serializeForAPI(summaryData: SummaryData): Record<string, any> {
    return {
      name: summaryData.name,
      count: summaryData.count,
      properties: summaryData.properties || {},
    };
  }

  /**
   * Deserialize summary data from storage/API
   */
  static deserializeFromStorage(data: Record<string, any>): SummaryData | null {
    try {
      const summaryData: SummaryData = {
        name: data.name,
        count: data.count,
        properties: data.properties || {},
      };

      return SummaryDataUtil.validateSummaryData(summaryData) ? summaryData : null;
    } catch (error) {
      return null;
    }
  }
}

/**
 * Summary aggregator for combining multiple summaries
 */
export class SummaryAggregator {
  private summaries: Map<string, SummaryData> = new Map();

  /**
   * Add a summary to the aggregator
   */
  addSummary(summaryData: SummaryData): void {
    if (!SummaryDataUtil.validateSummaryData(summaryData)) {
      throw new Error('Invalid summary data');
    }

    const existing = this.summaries.get(summaryData.name);
    if (existing) {
      // Merge with existing summary
      const merged = SummaryDataUtil.mergeSummaries(existing, summaryData);
      this.summaries.set(summaryData.name, merged);
    } else {
      // Add new summary
      this.summaries.set(summaryData.name, { ...summaryData });
    }
  }

  /**
   * Add multiple summaries
   */
  addSummaries(summaries: SummaryData[]): void {
    summaries.forEach(summary => this.addSummary(summary));
  }

  /**
   * Get all aggregated summaries
   */
  getSummaries(): SummaryData[] {
    return Array.from(this.summaries.values());
  }

  /**
   * Get a specific summary by name
   */
  getSummary(name: string): SummaryData | undefined {
    return this.summaries.get(name);
  }

  /**
   * Get the number of aggregated summaries
   */
  getCount(): number {
    return this.summaries.size;
  }

  /**
   * Clear all summaries
   */
  clear(): void {
    this.summaries.clear();
  }

  /**
   * Remove a specific summary
   */
  removeSummary(name: string): boolean {
    return this.summaries.delete(name);
  }

  /**
   * Check if aggregator is empty
   */
  isEmpty(): boolean {
    return this.summaries.size === 0;
  }

  /**
   * Get summary names
   */
  getSummaryNames(): string[] {
    return Array.from(this.summaries.keys());
  }

  /**
   * Get total count across all summaries
   */
  getTotalCount(): number {
    return Array.from(this.summaries.values()).reduce((total, summary) => total + summary.count, 0);
  }

  /**
   * Merge another aggregator into this one
   */
  merge(other: SummaryAggregator): void {
    this.addSummaries(other.getSummaries());
  }

  /**
   * Create a copy of this aggregator
   */
  clone(): SummaryAggregator {
    const clone = new SummaryAggregator();
    clone.addSummaries(this.getSummaries());
    return clone;
  }
} 