using FlynticStudio.Data.Entities;
using FlynticStudio.Data.Enums;

namespace FlynticStudio.Data.Repositories;

/// <summary>
/// Repository interface for managing drone components
/// </summary>
public interface IComponentRepository
{
    IEnumerable<DroneComponent> GetAll();
    DroneComponent? GetById(string id);
    IEnumerable<DroneComponent> GetByType(ComponentType type);
    DroneComponent Add(DroneComponent component);
    DroneComponent? Update(DroneComponent component);
    bool Delete(string id);
}
