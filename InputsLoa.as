string filename="";
array<TimedState> states;


bool se=false;
uint lastIndex = 0;
int lastTime = -2540;
int time = 0;
void OnRunStep(SimulationManager@ simManager)
{
    lastTime = time;
    if(filename=="" or states.Length==0){
        return;
    }
    time = simManager.RaceTime;
    
    // PRIMARY RESET LOGIC: Check for race restart or respawn (time loop) and reload the file
    // This is the ONLY place that sets se=false to resume playback.
    if(time<=lastTime){
        lastIndex = 0;
        se=false;
        CommandList list(filename);
        list.Process();
        SetCurrentCommandList(list);
    }
    
    // Only continue if the race is sufficiently started and control hasn't been seized
    if(time < 10 or se or lastIndex+1 >= states.Length){
        return;
    }   
    
    // Advance the index to the next recorded state if its time has passed
    if(states[lastIndex+1].time <= time-10){
        lastIndex++;
    }
    
    // Get current input and compare with the recorded state
    InputState inputState = simManager.GetInputState();
    TimedState currentState = TimedState(time, inputState.Up?1:0, inputState.Down?1:0, inputState.Steer, inputState.Left?1:0, inputState.Right?1:0, 0);
    
    // If input matches (excluding respawn state), do nothing
    if(states[lastIndex].equals(currentState)){
        return;
    }
    
    // --- FINAL INPUT SEIZURE LOGIC ---
    
    // Input mismatch detected (manual key press).
    
    // Check if there's actual command text (a key press/release event)
    string inputCommandsText = simManager.InputEvents.ToCommandsText();

    // Only set se=true and abandon playback if a real command was generated.
    if (inputCommandsText != "") {
        // DO NOT call SetCurrentCommandList(list). This prevents the duplicate command.
        // We let the manual input process via the game engine.
        se = true; 
    }
    // If the input mismatch was just a subtle steer difference (inputCommandsText is empty),
    // we continue the loop, trusting the recorded inputs to take precedence.
}
// ****************************************

// The logic here remains the same: reset index, but let OnRunStep control se=false.
void OnCommandListChanged(CommandList@ prev, CommandList@ current, CommandListChangeReason reason)
{
    if (current is null || current.InputCommands.Length == 0)
    {
        lastIndex = 0;
    }
}
// ******************************************************

void OnSimulationEnd(SimulationManager@ simManager, SimulationResult result)
{
    if(filename!="")
        LoaInputFile(0,0,"",{filename});
}


class TimedState{
    int time;
    uint accel;
    uint brake;
    int steer;
    uint left;
    uint right;
    uint respawn;
    TimedState(int time, uint accel, uint brake, int steer, uint left, uint right, uint respawn){
        this.time = time;
        this.accel = accel;
        this.brake = brake;
        this.steer = steer;
        this.left = left;
        this.right = right;
        this.respawn = respawn;
    }
    TimedState(){}
    bool equals(TimedState other){
        return this.accel == other.accel && this.brake == other.brake && this.steer == other.steer && this.left == other.left && this.right == other.right && this.respawn == other.respawn;
    }
    string opImplConv() const{
        return "Time: " + time + " Accel: " + accel + " Brake: " + brake + " Steer: " + steer + " Left: " + left + " Right: " + right + " Respawn: " + respawn;
    }
}

void LoaInputFile(int fromTime, int toTime, const string&in commandLine, const array<string>&in args) {
    string t="";
    for(uint i = 0; i < args.Length; i++){
        t+=args[i]+ "";
    }
    CommandList load = CommandList();
    load.Content = "load " + t;
    load.Process(CommandListProcessOption::ExecuteImmediately);
    try{
        
        filename = args[0];
        CommandList list=CommandList(filename);
        list.Process(CommandListProcessOption::OnlyParse);
        states.Clear();
        TimedState lastState = TimedState(0,0,0,0,0,0,0);
        for (uint i = 0; i < list.InputCommands.Length; i++) {
            auto cmd = list.InputCommands[i];
            if (cmd.Timestamp!=lastState.time){
                states.Add(lastState);
                lastState = TimedState(cmd.Timestamp, lastState.accel, lastState.brake, lastState.steer, lastState.left, lastState.right, lastState.respawn);
            }
            switch(cmd.Type){
                case InputType::Up:
                    lastState.accel = cmd.State;
                    break;
                case InputType::Down:
                    lastState.brake = cmd.State;
                    break;
                case InputType::Left:
                    lastState.left = cmd.State;
                    break;
                case InputType::Right:
                    lastState.right = cmd.State;
                    break;
                case InputType::Steer:
                    lastState.steer = cmd.State;
                    break;
                case InputType::Respawn:
                    lastState.respawn = cmd.State;
                    break;

            }
        }
        states.Add(lastState);
        
        lastIndex = 0;
        se=false;
    }
    catch{;}
}

void UnloaInputFile(int fromTime, int toTime, const string&in commandLine, const array<string>&in args) {
    CommandList load = CommandList();
    load.Content = "unload";
    load.Process(CommandListProcessOption::ExecuteImmediately);
    filename = "";
    states.Clear();
}

void Main()
{
    RegisterCustomCommand("loa", "Loa input file", LoaInputFile);
    RegisterCustomCommand("unloa", "Unloa input file", UnloaInputFile);
}

PluginInfo@ GetPluginInfo()
{
    auto info = PluginInfo();
    info.Name = "Race Control";
    info.Author = "Skycrafter";
    info.Version = "v1.0.0";
    info.Description = "As soon as a key is pressed during the race, hand over the control";
    return info;
}