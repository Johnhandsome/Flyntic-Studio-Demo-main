using FlynticStudio.Data.Entities;

namespace FlynticStudio.Services;

/// <summary>
/// Service interface for drone calculation operations
/// </summary>
public interface IDroneCalculationService
{
    DroneCalculationResult CalculatePerformance(IEnumerable<PlacedComponent> components);
    double CalculateTotalWeight(IEnumerable<PlacedComponent> components);
    double CalculateTotalThrust(IEnumerable<PlacedComponent> components);
    double CalculateThrustToWeightRatio(IEnumerable<PlacedComponent> components);
    double CalculateEstimatedFlightTime(IEnumerable<PlacedComponent> components);
    double CalculateTotalPowerConsumption(IEnumerable<PlacedComponent> components);
    bool ValidateConfiguration(IEnumerable<PlacedComponent> components, out List<string> errors);
}
