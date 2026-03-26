using FlynticStudio.Data.Entities;
using FlynticStudio.Data.DTOs;
using FlynticStudio.Data.Enums;

namespace FlynticStudio.Services;

/// <summary>
/// Service interface for drone assembly operations
/// </summary>
public interface IDroneAssemblyService
{
    IEnumerable<ComponentDto> GetAvailableComponents();
    IEnumerable<ComponentDto> GetComponentsByType(ComponentType type);
    ComponentDto? GetComponentById(string id);
    ConfigurationDto GetCurrentConfiguration();
    PlacedComponentDto PlaceComponent(PlaceComponentRequest request);
    PlacedComponentDto? UpdatePlacedComponent(UpdatePlacedComponentRequest request);
    bool RemovePlacedComponent(string instanceId);
    void ClearAllComponents();
    HierarchyNodeDto GetHierarchy();
    HierarchyNodeDto AddLayer(string name, string? parentId);
    bool MoveNodeToParent(string nodeId, string newParentId);
    bool DeleteLayer(string layerId);
    SimulationResultDto StartSimulation();
    SimulationResultDto PauseSimulation();
    SimulationResultDto StopSimulation();
    SimulationState GetSimulationState();
}
