# Usage: vivado -mode batch -source scripts/create_project.tcl
# Optional: -tclargs build/another-local-project
set repo_root [file normalize [file join [file dirname [info script]] ..]]
source [file join $repo_root scripts sources.tcl]
set output_dir [file join $repo_root build nexys_a7_100t]
if {[info exists argc] && $argc > 1} {
    error "Expected at most one argument: local output directory"
}
if {[info exists argc] && $argc == 1} {
    set output_dir [file normalize [file join $repo_root [lindex $argv 0]]]
}
if {[file exists [file join $output_dir amd_fpga.xpr]]} {
    error "Project already exists: $output_dir. Open it or choose a new output directory."
}
# Validate the manifest before creating anything.
foreach relative_path [concat $rtl_files $tb_files $xdc_files] {
    if {[file pathtype $relative_path] ne "relative"} {
        error "Source paths must be relative: $relative_path"
    }
    if {![file isfile [file join $repo_root $relative_path]]} {
        error "Missing source file: $relative_path"
    }
}
create_project amd_fpga $output_dir -part $fpga_part
set_property target_language VHDL [current_project]
foreach relative_path $rtl_files {
    set source_path [file join $repo_root $relative_path]
    add_files -norecurse -fileset sources_1 $source_path
    set_property file_type {VHDL 2008} [get_files $source_path]
}
foreach relative_path $tb_files {
    set source_path [file join $repo_root $relative_path]
    add_files -norecurse -fileset sim_1 $source_path
    set_property file_type {VHDL 2008} [get_files $source_path]
}
foreach relative_path $xdc_files {
    add_files -norecurse -fileset constrs_1 [file join $repo_root $relative_path]
}
if {$rtl_top ne ""} {
    set_property top $rtl_top [get_filesets sources_1]
}
if {$simulation_top ne ""} {
    set_property top $simulation_top [get_filesets sim_1]
}
if {[llength $rtl_files] > 0} {
    update_compile_order -fileset sources_1
}
if {[llength $tb_files] > 0} {
    update_compile_order -fileset sim_1
}
puts "Created project: [file join $output_dir amd_fpga.xpr]"
puts "Tool: [version -short]; part: $fpga_part"
puts "RTL files: [llength $rtl_files]; testbench files: [llength $tb_files]"
puts "No simulation, synthesis, implementation or programming was performed."
