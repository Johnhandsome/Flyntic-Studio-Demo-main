using FlynticStudio.Data.Entities;
using FlynticStudio.Data.Enums;

namespace FlynticStudio.Services;

/// <summary>
/// Service for calculating drone performance metrics
/// </summary>
public class DroneCalculationService : IDroneCalculationService
{
    public DroneCalculationResult CalculatePerformance(IEnumerable<PlacedComponent> components)
    {
        var componentsList = components.ToList();
        var errors = new List<string>();
        var isValid = ValidateConfiguration(componentsList, out errors);
        
        var result = new DroneCalculationResult
        {
            TotalWeight = CalculateTotalWeight(componentsList),
            TotalThrust = CalculateTotalThrust(componentsList),
            ThrustToWeightRatio = CalculateThrustToWeightRatio(componentsList),
            EstimatedFlightTime = CalculateEstimatedFlightTime(componentsList),
            TotalPowerConsumption = CalculateTotalPowerConsumption(componentsList),
            IsValid = isValid,
            ValidationErrors = errors
        };

        // Set performance rating
        if (result.ThrustToWeightRatio >= 4)
            result.PerformanceRating = "Racing";
        else if (result.ThrustToWeightRatio >= 2.5)
            result.PerformanceRating = "Freestyle";
        else if (result.ThrustToWeightRatio >= 1.5)
            result.PerformanceRating = "Cinematic";
        else if (result.ThrustToWeightRatio >= 1.1)
            result.PerformanceRating = "Stable";
        else
            result.PerformanceRating = "Underpowered";

        return result;
    }

    public double CalculateTotalWeight(IEnumerable<PlacedComponent> components)
    {
        return components.Sum(c => c.Weight);
    }

    public double CalculateTotalThrust(IEnumerable<PlacedComponent> components)
    {
        // Thrust comes from motors (in kg per motor)
        var motors = components.Where(c => c.ComponentType == ComponentType.Motor);
        return motors.Sum(m => m.Thrust * 1000); // Convert kg to grams
    }

    public double CalculateThrustToWeightRatio(IEnumerable<PlacedComponent> components)
    {
        var totalWeight = CalculateTotalWeight(components);
        var totalThrust = CalculateTotalThrust(components);
        
        if (totalWeight <= 0)
            return 0;
        
        return Math.Round(totalThrust / totalWeight, 2);
    }

    public double CalculateEstimatedFlightTime(IEnumerable<PlacedComponent> components)
    {
        var componentsList = components.ToList();
        var batteries = componentsList.Where(c => c.ComponentType == ComponentType.Battery).ToList();
        
        if (!batteries.Any())
            return 0;
        
        var totalCapacity = batteries.Sum(b => b.Capacity); // mAh
        var totalPowerConsumption = CalculateTotalPowerConsumption(componentsList); // Watts
        
        if (totalPowerConsumption <= 0)
            return 0;
        
        var averageVoltage = batteries.Average(b => b.Voltage);
        
        // Flight time = Capacity * Average Voltage * 0.8 (efficiency) / Power / 60 (minutes)
        var flightTimeMinutes = (totalCapacity * averageVoltage * 0.8) / (totalPowerConsumption * 1000) * 60;
        
        return Math.Round(flightTimeMinutes, 1);
    }

    public double CalculateTotalPowerConsumption(IEnumerable<PlacedComponent> components)
    {
        // Sum up power consumption from all components (in Watts)
        return components.Sum(c => c.PowerConsumption);
    }

    public bool ValidateConfiguration(IEnumerable<PlacedComponent> components, out List<string> errors)
    {
        errors = new List<string>();
        var componentsList = components.ToList();
        
        // Check for frame
        var frames = componentsList.Where(c => c.ComponentType == ComponentType.Frame).ToList();
        if (!frames.Any())
        {
            errors.Add("No frame component found. Please add a frame.");
        }
        else if (frames.Count > 1)
        {
            errors.Add("Multiple frames detected. Only one frame is allowed.");
        }
        
        // Check for motors (typically 4 for quadcopter)
        var motors = componentsList.Where(c => c.ComponentType == ComponentType.Motor).ToList();
        if (motors.Count < 4)
        {
            errors.Add($"Not enough motors ({motors.Count}/4). Quadcopters require 4 motors.");
        }
        
        // Check for battery
        var batteries = componentsList.Where(c => c.ComponentType == ComponentType.Battery).ToList();
        if (!batteries.Any())
        {
            errors.Add("No battery found. Please add a battery.");
        }
        
        // Check for flight controller
        var flightControllers = componentsList.Where(c => c.ComponentType == ComponentType.FlightController).ToList();
        if (!flightControllers.Any())
        {
            errors.Add("No flight controller found. Please add a flight controller.");
        }
        else if (flightControllers.Count > 1)
        {
            errors.Add("Multiple flight controllers detected. Only one is allowed.");
        }
        
        // Check for ESC
        var escs = componentsList.Where(c => c.ComponentType == ComponentType.ESC).ToList();
        if (!escs.Any())
        {
            errors.Add("No ESC found. Please add an Electronic Speed Controller.");
        }
        
        // Check thrust-to-weight ratio
        var twr = CalculateThrustToWeightRatio(componentsList);
        if (twr > 0 && twr < 1.1)
        {
            errors.Add($"Thrust-to-weight ratio ({twr}) is too low. The drone may not fly properly.");
        }
        
        return !errors.Any();
    }
}
