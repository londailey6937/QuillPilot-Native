#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'QuillPilot/QuillPilot.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.first
file_path = 'QuillPilot/QuillPilot/Models/DecisionBeliefLoop.swift'

# Check if file already exists in project
existing = project.files.find { |f| f.path == file_path }

if existing.nil?
  # Add file to project
  file_ref = project.new_file(file_path)
  target.add_file_references([file_ref])
  project.save
  puts "Added DecisionBeliefLoop.swift to project"
else
  puts "File already in project"
end
