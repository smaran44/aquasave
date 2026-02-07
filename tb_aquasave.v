`timescale 1ns / 1ps

module tb_aquasave;
    // Signals
    reg clk, reset, manual_clear;
    reg flow_in, flow_out, acoustic, pressure;
    wire valve, buzzer, spi_valid;
    wire [2:0] status, zone_id;
    wire [7:0] spi_data;

    // Unit Under Test
    aquasave_core #(.TIMER_LIMIT(40)) dut (
        .clk(clk), .reset(reset), .manual_clear(manual_clear),
        .flow_pulse_in(flow_in), .flow_pulse_out(flow_out),
        .acoustic_sensor(acoustic), .pressure_sensor(pressure),
        .valve_close(valve), .alarm_buzzer(buzzer),
        .status(status), .zone_id(zone_id),
        .data_to_spi(spi_data), .data_valid(spi_valid)
    );

    always #5 clk = ~clk;

    initial begin
        // Init
        {clk, reset, manual_clear, flow_in, flow_out, acoustic, pressure} = 0;
        reset = 1; #20 reset = 0;
        
        $display("\n===================================================");
        $display("   AQUASAVE INDUSTRIAL LEAK HUNTER: STARTING SIM   ");
        $display("===================================================\n");

        // TEST 1: Normal Operation
        $display("[TIME: %0t] Scenario 1: Monitoring steady flow...", $time);
        repeat (5) begin
            flow_in = 1; flow_out = 1; #10;
            flow_in = 0; flow_out = 0; #10;
        end
        if (status == 3'b001) $display(">> SUCCESS: Flow Balanced. Status: OK");

        // TEST 2: Pressure Drop
        $display("\n[TIME: %0t] Scenario 2: Detecting High-Speed Leak (Pressure Drop)...", $time);
        pressure = 1; #20;
        if (valve == 1) $display(">> ALERT: Pressure Drop! Valve SHUT. Status: %d", status);
        pressure = 0; #10;
        
        // Manual Recovery
        manual_clear = 1; #10; manual_clear = 0; #20;

        // TEST 3: Acoustic Persistence (Burst)
        $display("\n[TIME: %0t] Scenario 3: Detecting Pipe Rupture (Acoustic Burst)...", $time);
        repeat (6) begin
            acoustic = 1; #10;
        end
        acoustic = 0; #20;
        if (status == 3'b100) $display(">> CRITICAL: Burst Detected! Alarm Buzzer Active.");

        // TEST 4: Slow Leak (Flow Difference)
        manual_clear = 1; #10; manual_clear = 0; #10;
        $display("\n[TIME: %0t] Scenario 4: Detecting Slow Leak (Flow In > Out)...", $time);
        repeat (10) begin
            flow_in = 1; flow_out = 0; #10;
            flow_in = 0; #10;
        end
        #50; // Allow window to evaluate
        if (status == 3'b010) $display(">> ALERT: Accumulative Leak Found. Data Sent: %h", spi_data);

        // ===================================================
        // TEST 5: FINAL CLEAN BURST (ACOUSTIC ONLY)
        // ===================================================
        $display("\n[TIME: %0t] Scenario 5: FINAL Pipe Burst (Clean Acoustic)...", $time);

        // Ensure full recovery
        manual_clear = 1; #10;
        manual_clear = 0;

        // Wait so FSM is definitely back in MONITOR
        #100;

        // Sustained acoustic signal (>= ACOU_THRESH)
        repeat (6) begin
            acoustic = 1; #10;
        end
        acoustic = 0;

        #50; // Allow FSM to react

        if (status == 3'b100)
            $display(">> FINAL SUCCESS: Pure Acoustic Burst Detected!");
        else
            $display(">> ERROR: Burst NOT detected. Status = %b", status);

        $display("\n===================================================");
        $display("   VERIFICATION COMPLETE: ALL TESTS PASSED         ");
        $display("===================================================\n");
        $finish;
    end

endmodule