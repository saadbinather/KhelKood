/**
 * PricingStrategy - Strategy Pattern for Pricing Calculations
 * 
 * SOLID Principles Applied:
 * 1. Single Responsibility: Each strategy handles one type of pricing
 * 2. Open/Closed: New pricing strategies can be added without modifying existing code
 * 3. Liskov Substitution: All strategies can be used interchangeably
 * 4. Interface Segregation: Clean interface for pricing calculations
 */

/**
 * Abstract PricingStrategy class
 */
export class PricingStrategy {
  constructor() {
    if (new.target === PricingStrategy) {
      throw new Error("Cannot instantiate abstract class PricingStrategy");
    }
  }

  /**
   * Calculate price based on strategy
   * @param {Object} courtData - Court data
   * @param {Date} startTime - Start time
   * @param {Date} endTime - End time
   * @returns {Object} Pricing details
   */
  calculate(courtData, startTime, endTime) {
    throw new Error("Method 'calculate()' must be implemented");
  }

  /**
   * Get duration in hours
   * @param {Date} startTime - Start time
   * @param {Date} endTime - End time
   * @returns {number} Duration in hours
   */
  getDurationHours(startTime, endTime) {
    return (new Date(endTime) - new Date(startTime)) / (1000 * 60 * 60);
  }
}

/**
 * Cricket Pricing Strategy
 */
export class CricketPricingStrategy extends PricingStrategy {
  calculate(courtData, startTime, endTime) {
    const durationHours = this.getDurationHours(startTime, endTime);
    const hourlyRate = courtData.cricketPricePerHour || 1000;
    
    return {
      sportType: 'cricket',
      hourlyRate,
      durationHours,
      totalAmount: Math.round(durationHours * hourlyRate),
    };
  }
}

/**
 * Futsal/Football Pricing Strategy
 */
export class FutsalPricingStrategy extends PricingStrategy {
  calculate(courtData, startTime, endTime) {
    const durationHours = this.getDurationHours(startTime, endTime);
    const hourlyRate = courtData.futsalPricePerHour || 500;
    
    return {
      sportType: 'futsal',
      hourlyRate,
      durationHours,
      totalAmount: Math.round(durationHours * hourlyRate),
    };
  }
}

/**
 * Padel Pricing Strategy
 */
export class PadelPricingStrategy extends PricingStrategy {
  calculate(courtData, startTime, endTime) {
    const durationHours = this.getDurationHours(startTime, endTime);
    const hourlyRate = courtData.padelPricePerHour || 800;
    
    return {
      sportType: 'padel',
      hourlyRate,
      durationHours,
      totalAmount: Math.round(durationHours * hourlyRate),
    };
  }
}

/**
 * Pricing Strategy Factory
 */
export class PricingStrategyFactory {
  /**
   * Get pricing strategy based on sport type
   * @param {string} sportType - Sport type
   * @returns {PricingStrategy} Pricing strategy instance
   */
  static getStrategy(sportType) {
    const normalizedSport = (sportType || '').toLowerCase();
    
    switch (normalizedSport) {
      case 'cricket':
        return new CricketPricingStrategy();
      case 'futsal':
      case 'football':
        return new FutsalPricingStrategy();
      case 'padel':
        return new PadelPricingStrategy();
      default:
        return new FutsalPricingStrategy(); // Default
    }
  }
}

