namespace FlynticStudio.Data.Entities;

/// <summary>
/// Results from drone performance calculations
/// </summary>
public class DroneCalculationResult
{
    // Weight calculations
    public double TotalWeight { get; set; } // in grams
    public double FrameWeight { get; set; }
    public double MotorsWeight { get; set; }
    public double BatteryWeight { get; set; }
    public double OtherComponentsWeight { get; set; }
    
    // Thrust calculations
    public double TotalThrust { get; set; } // in kg
    public double ThrustPerMotor { get; set; }
    public int MotorCount { get; set; }
    
    // Performance ratios
    public double ThrustToWeightRatio { get; set; }
    public string PerformanceRating { get; set; } = string.Empty;
    public bool CanFly => ThrustToWeightRatio > 1.0;
    public string FlightCapability => ThrustToWeightRatio switch
    {
        < 1.0 => "Cannot fly",
        < 1.5 => "Marginal",
        < 2.0 => "Normal",
        < 3.0 => "Sporty",
        _ => "Acrobatic"
    };
    
    // Power calculations
    public double TotalPowerConsumption { get; set; } // in watts
    public double BatteryCapacity { get; set; } // in mAh
    public double BatteryVoltage { get; set; } // in volts
    public double EstimatedFlightTime { get; set; } // in minutes
    
    // Status
    public List<string> Warnings { get; set; } = new();
    public List<string> ValidationErrors { get; set; } = new();
    public bool IsValid { get; set; } = true;
    
    // Timestamp
    public DateTime CalculatedAt { get; set; } = DateTime.UtcNow;
}
