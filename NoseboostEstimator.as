PluginInfo@ GetPluginInfo() {
    PluginInfo@ info = PluginInfo();
    info.Name = "Noseboost Estimator";
    info.Author = "igntuL";
    info.Version = "1.0";
    return info;
}

array<vec3> g_points;
float g_averageSpeedKmh = 850.0;
int g_noseTime = 0;
bool g_headerExpanded = true;

void Main() {
    RegisterSettingsPage("Noseboost Est.", DrawSettingsPage);
}

float GetSpeedInMetersPerSecond() {
    return g_averageSpeedKmh / 3.6;
}

float CalculateTotalDistance() {
    float totalDistance = 0.0;
    for (uint i = 1; i < g_points.Length; i++) {
        totalDistance += Math::Distance(g_points[i - 1], g_points[i]);
    }
    return totalDistance;
}

int CalculateNoseboostingTime() {
    float totalDistance = CalculateTotalDistance();
    float speedMps = GetSpeedInMetersPerSecond();
    return (speedMps > 0.0) ? int((totalDistance / speedMps) * 1000) : 0;
}

int GetCurrentRaceTime() {
    auto simManager = GetSimulationManager();
    return (simManager !is null) ? simManager.RaceTime : 0;
}

void DrawSettingsPage() {
    UI::Text("Noseboost Estimator");
    UI::TextDimmed("Place your points along the path you intend to noseboost. This plugin will estimate the travel time at the given average speed, and help you choose the best path if you have multiple options.");
    UI::Dummy(vec2(0, 10));

    g_headerExpanded = UI::CollapsingHeader("Saved Points");
    if (g_headerExpanded) {
        for (uint i = 0; i < g_points.Length; i++) {
            string index = Text::FormatInt(i + 1, "", 2);
            string x = Text::FormatFloat(g_points[i].x, "", 11, 3);
            string y = Text::FormatFloat(g_points[i].y, "", 11, 3);
            string z = Text::FormatFloat(g_points[i].z, "", 11, 3);
            UI::Text("Point " + index + ":  " + x + "   " + y + "   " + z);
        }
        if (g_points.Length == 0) {
            UI::Text("No points saved.");
        }
    }

    UI::Dummy(vec2(0, 5));

    float buttonWidth = 140.0;

    if (UI::Button("Add Point", vec2(buttonWidth, 0))) {
        SavePoint();
    }
    UI::SameLine();

    string clearLabel = "Clear " + g_points.Length + (g_points.Length == 1 ? " Point" : " Points");
    if (UI::Button(clearLabel, vec2(buttonWidth, 0))) {
        g_points.Resize(0);
    }

    UI::Dummy(vec2(0, 15));

    UI::PushItemWidth(285);
    g_averageSpeedKmh = UI::SliderFloat("Est. Average Speed", g_averageSpeedKmh, 500.0, 1000.0);
    g_noseTime = UI::InputTime("Nose Position Time", g_noseTime);
    UI::PopItemWidth();

    UI::TextDimmed("Select the time your noseboost begins - when you are or expect to be at Point 1.");

    UI::Dummy(vec2(0, 5));

    if (UI::Button("Copy Current Race Time", vec2(285, 0))) {
        g_noseTime = GetCurrentRaceTime();
    }

    UI::Dummy(vec2(0, 10));

    float totalDistance = CalculateTotalDistance();
    int noseboostTime = CalculateNoseboostingTime();
    int totalTime = noseboostTime + g_noseTime;

    if (UI::BeginTable("ResultsTable", 2)) {
        // Distance
        UI::TableNextColumn(); UI::Text("Noseboosting Distance:");
        UI::TableNextColumn(); 
        UI::PushItemWidth(140);
        UI::Text(totalDistance + " meters");
        UI::PopItemWidth();

        // Boost time
        UI::TableNextColumn(); UI::Text("Noseboosting Time:");
        UI::TableNextColumn();
        UI::PushItemWidth(140);
        UI::Text(Time::Format(noseboostTime) + " seconds");
        UI::PopItemWidth();

        // Total time
        UI::TableNextColumn(); UI::Text("Total Time:");
        UI::TableNextColumn();
        UI::PushItemWidth(140);
        UI::Text(Time::Format(totalTime) + " seconds");
        UI::PopItemWidth();

        UI::EndTable();
    }
}

void SavePoint() {
    auto camera = GetCurrentCamera();
    vec3 pos;
    if (camera !is null && camera.get_NameId() == "") {
        pos = camera.Location.Position;
    } else {
        pos = GetSimulationManager().Dyna.CurrentState.Location.Position;
    }
    g_points.Add(pos);
}
