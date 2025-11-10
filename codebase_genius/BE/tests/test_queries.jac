import from analyzer_utils { get_callers, get_callees, get_file_entities }
import json;

with entry {
    # Load the analysis data
    with open("outputs/analyzer_output.json", "r") as f {
        data = json.load(f);
    }
    
    call_graph = data.get("call_graph", {});
    files = data.get("files", []);
        print("📁 Files analyzed:");

    for file_info in files {
        fname = file_info.get("file", "?");
        fcount = len(file_info.get("functions", []));
        ccount = len(file_info.get("classes", []));
        print(f"  {fname}: {ccount} classes, {fcount} functions");
    }
    
    # Show which files DO have content
    print("✅ Files with entities:");
    for file_info in files {
        if len(file_info.get("functions", [])) > 0 or len(file_info.get("classes", [])) > 0 {
            print(f"  {file_info.get('file', '?')}");
        }
    }

    # Test queries
    print("🧪 Testing Query Functions\n");
    
    # Test 1: Who calls run_analysis?
    callers = get_callers("run_analysis", call_graph);
    print(f"1️⃣ Callers of 'run_analysis': {callers}");
    
    # Test 2: What does execute_analysis call?
    callees = get_callees("execute_analysis", call_graph);
    print(f"2️⃣ 'execute_analysis' calls: {callees}");
    
    # Test 3: Get entities from main.jac
    entities = get_file_entities("main.jac", files);
    print(f"3️⃣ main.jac has {len(entities.get('classes', []))} classes, {len(entities.get('functions', []))} functions");
}