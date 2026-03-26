using FlynticStudio.Data.Repositories;
using FlynticStudio.Services;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllersWithViews();

// Register Repository Layer (Singleton for in-memory storage)
builder.Services.AddSingleton<IComponentRepository, ComponentRepository>();
builder.Services.AddSingleton<IDroneConfigurationRepository, DroneConfigurationRepository>();

// Register Service Layer
builder.Services.AddScoped<IDroneCalculationService, DroneCalculationService>();
builder.Services.AddScoped<IDroneAssemblyService, DroneAssemblyService>();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseRouting();

app.UseAuthorization();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();
