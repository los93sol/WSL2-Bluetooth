#See https://aka.ms/customizecontainer to learn how to customize your debug container and how Visual Studio uses this Dockerfile to build your images for faster debugging.

FROM mcr.microsoft.com/dotnet/aspnet:8.0.0-rc.2 AS base

RUN apt-get update && \
    apt-get install -y usbutils usbip bluez && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

USER app
WORKDIR /app
EXPOSE 8080
EXPOSE 8081

FROM mcr.microsoft.com/dotnet/sdk:8.0.100-rc.2 AS build
ARG BUILD_CONFIGURATION=Release
WORKDIR /src
COPY ["WSL2-Bluetooth/WSL2-Bluetooth.csproj", "WSL2-Bluetooth/"]
RUN dotnet restore "./WSL2-Bluetooth/./WSL2-Bluetooth.csproj"
COPY . .
WORKDIR "/src/WSL2-Bluetooth"
RUN dotnet build "./WSL2-Bluetooth.csproj" -c $BUILD_CONFIGURATION -o /app/build

FROM build AS publish
ARG BUILD_CONFIGURATION=Release
RUN dotnet publish "./WSL2-Bluetooth.csproj" -c $BUILD_CONFIGURATION -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "WSL2-Bluetooth.dll"]