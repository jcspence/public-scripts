#!/bin/env ruby

# Copyright Carey Spence 2016

# This file backs up local data to a server over
#  (for the most part) sftp.

require 'json'
require 'open3'
require 'syslog/logger'
require 'socket'
require 'optparse'

# SftpSink: Models a backup sink which can be accessed over sftp.
class SftpSink
  attr_reader :name

  def initialize(name: nil, hostname:, username:, directory:, port:, keyfile:)
    # Sets variables for a backup sink.
    # @param hostname [String] Hostname to connect to.
    # @param username [String] User to connect as.
    # @param directory [String] Directory to put backups in (root).
    # @param port [Fixnum] Port number to connect to.
    # @param keyfile [String] Path to SSH Keyfile.

    # TODO: Validate username, hostname, port, keyfile.

    # Ensure keyfile exists.
    fail ArgumentError, 'Keyfile given does not exist' unless File.file? keyfile

    @name = name || hostname
    @hostname = hostname
    @username = username
    # Ensure that directory has a trailing /.
    @directory = File.join(directory, '')
    @port = port
    @keyfile = keyfile
  end

  def duplicity_options(host:, name:)
    # Describe the backup target, for a given backup name, to duplicity
    # @param host [String] Name of the host whose data is backed up.
    # @param name [String] Name of the backup job.
    #                      e.g. 'root-home'
    # @return [Array] A string specifying the keyfile and a
    #                 string specifying how to connect to the sink.

    [
      "--ssh-options='-oIdentityFile=#{@keyfile}'",
      "pexpect+sftp://#{@username}@#{@hostname}:#{@port}/"\
                     "#{@directory}#{host}/#{name}/"
    ]
  end
end

# Constants for keeping track of error status in Job.
module Error
  YES = 2
  MAYBE = 1
  OK = 0
end

# Module for classes which need to call a logger, like Job or JobSet.
module Syslogs
  def log(string, level = Syslog::LOG_INFO)
    # Write a string to syslog.
    # This function is written so that I can implement other logging if
    #  desired.
    # @param string [String] String to log.
    # @param level [Fixnum] Priority level.

    # Log levels, from:
    #  http://ruby-doc.org/stdlib-2.3.1/libdoc/syslog/rdoc/Syslog.html
    # LOG_EMERG     System is unusable
    # LOG_ALERT     Action needs to be taken immediately
    # LOG_CRIT      A critical condition has occurred
    # LOG_ERR       An error occurred
    # LOG_WARNING   Warning of a possible problem
    # LOG_NOTICE    A normal but significant condition occurred
    # LOG_INFO      Informational message
    # LOG_DEBUG     Debugging information

    Syslog.log(level, "#{level} #{string}")
  end
end

# Job: A backup job (source folder and destination.)
class Job
  include Syslogs

  # Line in duplicity output used as header for statistics.
  DUPLICITY_STATS_HEADER = "--------------[ Backup Statistics ]--------------\n"

  def initialize(name:, path:, host:, sinks:, pass:,
                 exclude: [], monthly_full: true)
    # Store information on a backup Job.
    # @param name [String] Name of the backup job, e.g. 'root-home'.
    # @param path [String] Path to the folder to back up.
    # @param host [String] Hostname of machine that is running the backup.
    # @param sinks [Array] Array of backup sinks, e.g. instances of SftpSink.
    # @param pass [String] Encryption passphrase for duplicity.
    # @param exclude [Array] Paths to exclude. Default: []
    # @param monthly_full [Boolean] Full backup once a month? Default: true.

    # TODO: Input validation?

    @name = name
    @path = path
    @sinks = sinks
    @host = host
    @pass = pass
    @exclude = exclude
    @monthly_full = monthly_full
  end

  def duplicity_options(mode:)
    # Return any special duplicity options for this backup.
    # @param mode [Symbol] :backup or :verify
    # @return Options to give to duplicity.

    fail ArgumentError, 'mode must be :backup or :verify' unless
      %i(backup verify).include? mode

    opts = []

    # Run a full backup every so often.
    opts += ['--full-if-older-than', '1M'] if @monthly_full

    # Add exclusions.
    opts += @exclude.inject([]) { |a, e| a + ['--exclude', e] }

    opts
  end

  def call_duplicity_backup(sink:)
    # Call Duplicity and return output.
    # @param sink [Sink] Backup sink to use.
    # @return [String, Fixnum] Combined stdout and stderr
    #                          from duplicity, exit status.

    combined_out, status = Open3.capture2e(
      { 'PASSPHRASE' => @pass },
      'duplicity',
      '--allow-source-mismatch',
      '--exclude-if-present', '.nobackup',
      *duplicity_options(mode: :backup),
      @path,
      *sink.duplicity_options(host: @host, name: @name)
    )

    [combined_out, status.exitstatus]
  end

  def call_duplicity_verify(sink:)
    # Call Duplicity and return output.
    # @param sink [Sink] Backup sink to use.
    # @return [String, Fixnum] Combined stdout and stderr
    #                          from duplicity, exit status.

    combined_out, status = Open3.capture2e(
      { 'PASSPHRASE' => @pass },
      'duplicity', 'verify',
      '--allow-source-mismatch',
      '--exclude-if-present', '.nobackup',
      *duplicity_options(mode: :verify),
      *sink.duplicity_options(host: @host, name: @name),
      @path
    )

    [combined_out, status.exitstatus]
  end

  def parse_duplicity_log(log_str)
    # Parse the first part of Duplicity's output.
    # @param log [String] The first part of Duplicity's output.
    # @return error, full [Fixnum, Boolean] Any error flags set,
    #                                   whether it was a full backup.

    log_length = log_str.count("\n")

    # Note if this is a full backup.
    full = log_length == 3 &&
           log_str.lines[2] == 'Last full backup is too old, ' \
                               "forcing full backup\n"

    # Log is assumed to contain 2 or 3 lines; report about anything else.
    error = log_length == 2 || full ? Error::OK : Error::MAYBE

    # Detect error from bad encryption key.
    if log_length > 3 &&
       log_str.lines.include?("gpg: decryption failed: bad key\n")
      log 'Fail: Bad encryption key. Please fix backup spec.', Syslog::LOG_ERR
      error = Error::YES
    end

    # return
    [error, full]
  end

  def parse_duplicity_stats(stat_str)
    # Parse the second part of Duplicity's output.
    # @param stat_str [String] The second part of Duplicity's output.
    # @return stats, error [Hash, Fixnum] Statistics, Errors found
    #                                      from statistics.

    error = 0

    # Build an attribute => value dict:
    # Chomp off trailing \n, then build dict with .inject.
    stats = stat_str.lines.map(&:chomp).inject({}) do |memo, line|
      # Skip empty lines and -* border.
      # Next ends execution of block, 'returns' memo.
      next memo if /^-*$/ =~ line

      # Split line.
      key, val = line.split(' ', 2)

      # Return dict with new key, value.
      memo.merge(key => val)
    end

    # If there are errors, set error flag.
    error |= Error::YES if stats['Errors'] != '0'

    # return
    [stats, error]
  end

  def stats_access_human(stats, key)
    # Get human readable entry from stats hash.
    # @param stats [Hash] Stats hash.
    # @param key [String] Key for entry in stats hash.
    # @return The corresponding value, with leading number stripped.

    stats[key].gsub(/^\d+ \(/, '').gsub(/\)$/, '')
  end

  def backup_to_sink(sink:)
    # Back up to a given sink. Return results.
    # @param sink [Sink] Backup sink.
    # @return Array:
    #          error [Fixnum] Error flags.
    #          full [Boolean] Whether the backup was a full backup.
    #          output [String] Output from duplicity.
    #          stats [Hash] Duplicity statistics.

    # Run duplicity with the sink.
    output, exit_status = call_duplicity_backup(sink: sink)

    # Interpret output.
    log, stat_str = output.split(DUPLICITY_STATS_HEADER)

    # Parse log and get statistics.
    log_error, full   = parse_duplicity_log(log)
    stat_error = 0
    stats, stat_error = parse_duplicity_stats(stat_str) if stat_str

    # Determine error flags.
    error = log_error | stat_error
    error |= Error::YES if exit_status != 0

    # return
    [error, full, output, stats]
  end

  def verify_on_sink(sink:)
    # Check that backup is properly on sink.
    # @param sink [Sink] Backup sink.
    # @return Array:
    #          error [Fixnum] Error flags.
    #          output [String] Output from duplicity.

    # Run duplicity with the sink.
    output, exit_status = call_duplicity_verify(sink: sink)

    # Sets error flag iff duplicity returns nonzero.
    # From the man duplicity man page:
    # > Restore backup contents temporarily file by file and compare against the
    # > local path's contents. duplicity will exit with a non-zero error level
    # > if any files are different.
    error = exit_status == 0 ? Error::OK : Error::YES

    [error, output]
  end

  def log_single_backup_result(error:, sink:, output:, stats:, full:)
    # Log the result of backing up a job to a single sink.
    # @param error [Fixnum] Error flags.
    # @param sink [Sink] Backup sink in use.
    # @param output [String] Raw output from duplicity.
    # @param stats [Hash] Duplicity statistics.
    # @param full [Boolean] Whether backup was a full backup.

    # Show entire log if there was an error or 'maybe' condition.
    # In case of error,
    if error > 0
      # Log error if error known.
      log 'Error was detected:', Syslog::LOG_ERR if error & Error::YES > 0
      # Log if there 'may be' an error
      log 'Unrecognized output from duplicity:' if error & Error::MAYBE > 0

      # Log full duplicity output.
      output.lines.each { |line| log '> ' + line, Syslog::LOG_INFO }

    # Log success.
    else
      log((full ? '[Full] ' : '') + "Backup of #{@name} to #{sink.name} " \
          'completed successfully. ' \
          "Raw delta size: #{stats_access_human(stats, 'RawDeltaSize')}")
    end
  end

  def log_single_verify_result(error:, sink:, output:)
    # Log the result of verifying a job on a single sink.
    # @param error [Fixnum] Error flags.
    # @param sink [Sink] Backup sink in use.
    # @param output [String] Raw output from duplicity.

    # Show entire log if there was an error or 'maybe' condition.
    # In case of error,
    if error > 0
      # Log error if error known.
      log 'Error was detected:', Syslog::LOG_ERR if error & Error::YES > 0
      # Log if there 'may be' an error
      log 'Unrecognized output from duplicity:' if error & Error::MAYBE > 0

      # Log full duplicity output.
      output.lines.each { |line| log '> ' + line, Syslog::LOG_INFO }

    # Log success.
    else
      log "Verify of #{@name} on #{sink.name} completed successfully. "
    end
  end

  def run!
    # TODO: Perhaps move the chain of code leading to run! to a module, include.
    #       For modularity.
    # Run backup.
    # Inspired by older python backup script.
    # @return job_error [Fixnum]

    job_error = 0

    # For each sink.
    @sinks.each do |sink|
      log "Starting backup #{@name} to #{sink.name}."

      # Run backup to sink, parse output.
      error, full, output, stats = backup_to_sink sink: sink
      # Update this method's error flags.
      job_error |= error

      # Log job results.
      log_single_backup_result(error: error,   sink: sink,
                               output: output, stats: stats, full: full)
    end

    # return
    job_error
  end

  def verify!
    # TODO: Perhaps move the chain of code leading to verify! to a module,
    #       include. For modularity.
    # Verify a backup.
    # @return job_error [Fixnum]

    job_error = 0

    # For each sink.
    @sinks.each do |sink|
      log "Verifying backup #{@name} on #{sink.name}."

      # Run backup to sink, parse output.
      error, output = verify_on_sink sink: sink
      # Update this method's error flags.
      job_error |= error

      # Log job results.
      log_single_verify_result(error: error,   sink: sink, output: output)
    end

    # return
    job_error
  end
end

# Holds a set of jobs.
# Also keeps track of some common attributes, like the ssh keyfile and
# duplicity encryption password.
class JobSet
  include Syslogs # Provides log(String, Fixnum)

  attr_reader :name

  def initialize(name:, host:, jobs: [], dpass: nil, dsinks: [])
    # Sets variables for a backup sink.
    # @param name [String] Identifying name.
    # @param host [String] Name of host running backup.
    # @param jobs [Array] Array of jobs (instances of Job.)
    # @param dpass [String] Default encryption password for new jobs.
    #                       Default: nil.
    #                       // prob passed byval
    # @param dsinks [Array] Default sinks for new jobs.
    #                       // prob passed byref

    @name = name
    @jobs = jobs
    @dpass = dpass
    @dsinks = dsinks
    @host = host
  end

  def self.new_from_hash(hash:)
    # Creates and returns a new JobSet from a hash.
    # @param hash [Hash] Jobset specification.

    # Init jobset.
    jobset = JobSet.new(name:  hash[:name], host:  hash[:host],
                        dpass: hash[:pass])

    # Create jobs from hash.
    hash[:jobs].each do |job_hash|
      jobset.add_job(**job_hash)
    end

    # Create sftp backup sinks from hash.
    hash[:sftp_sinks].each do |sink_hash|
      # Remove invalid arguments which are in the config for
      # legacy or other reasons.
      %i(connect host).each { |sym| sink_hash.delete(sym) }
      # Add sink.
      jobset.add_sftp_sink(**sink_hash)
    end

    # return
    jobset
  end

  def push_job(job)
    # Add a Job to this JobSet.
    # @param job [Job] Job to add.
    # @return self

    fail ArgumentError, 'Please push an instance of Job.' unless job.is_a? Job

    @jobs.push(job)

    self
  end

  def add_job(kwargs)
    # Append a new job, created with the given kwargs.
    # Will specify default args if they exist.
    # @param kwargs [Hash] Arguments with which to create new job.
    # @return self

    # Defaults
    kwargs[:pass] ||= @dpass if @dpass
    kwargs[:host] ||= @host
    kwargs[:sinks] ||= @dsinks

    # XXX add warning on backup run with no sinks / jobset run with no jobs?

    push_job(Job.new(**kwargs))

    self
  end

  def add_sftp_sink(kwargs)
    # Append a new sftp sink, created with given kwargs.
    # @param kwargs [Hash] Arguments with which to create new job.
    # @return self

    @dsinks.push(SftpSink.new(**kwargs))

    self
  end

  def run!
    # Run each job. Keep track of errors, printing master P/F.
    # @return error [Fixnum] Error flags.

    # For each job
    error = @jobs.inject(0) do |memo, job|
      # Run job and OR the error into the memo, eventually returning the error.
      memo | job.run!
    end

    # Log notice.
    if error == 0
      # OK.
      log "[ OK ] Backup set #{@name} on #{@host} done.", Syslog::LOG_NOTICE
    else
      # TODO: show different output for fail vs unknown
      # FAIL.
      log("[FAIL] Backup set #{@name} on #{@host} is in error.",
          (error & Error::YES > 0 ? Syslog::LOG_ERR : Syslog::LOG_WARNING))
    end

    error
  end

  def verify!
    # Verify each job. Keep track of errors, printing master P/F.
    # @return error [Fixnum] Error flags.

    # For each job
    error = @jobs.inject(0) do |memo, job|
      # Run job and OR the error into the memo, eventually returning the error.
      memo | job.verify!
    end

    # Log notice.
    if error == 0
      # OK.
      log "[ OK ] Verified backup set #{@name} on #{@host}.", Syslog::LOG_NOTICE
    else
      # FAIL.
      log("[FAIL] Could not verify backup set #{@name} on #{@host}.",
          (error & Error::YES > 0 ? Syslog::LOG_ERR : Syslog::LOG_WARNING))
    end

    error
  end
end

# Some code to use when this script is run from the command line.
module Cli
  def self.parse_args
    # Parse arguments.
    # Leaves positional args? in ARGV for ARGF (used later.)
    # @return opt [Hash] Options.

    # Defaults
    opt = { verify: true }

    OptionParser.new do |opts|
      opts.banner = 'Usage: ruby_backup.rb [options] [backup_spec_file]'

      opts.on('-v', '--verify', 'Verify backup') do
        opt[:verify] = true
      end
      opts.on('-n', '--no-verify', 'Do not verify backup') do
        opt[:verify] = false
      end

      opts.on('-h', '--help', 'Prints this help') do
        puts opts
        exit
      end
    end.parse!

    # return
    opt
  end
end

# If this file is run itself - get a jobset spec from STDIN or a named file,
#  run that jobset.
if __FILE__ == $PROGRAM_NAME
  # Parse options
  opt = Cli.parse_args

  # Load a jobset specification from JSON.
  jobs_data = JSON.parse(ARGF.read, symbolize_names: true)
  jobs = JobSet.new_from_hash(hash: jobs_data)

  # Open connection to syslog.
  Syslog.open('ruby_backup.rb', Syslog::LOG_CONS | Syslog::LOG_PID)

  # Run that jobset.
  error = jobs.run!

  # Verify jobset, if requested.
  error |= jobs.verify! if opt[:verify]

  # Close connection to syslog
  Syslog.log(Syslog::LOG_INFO, "#{Syslog::LOG_INFO} Exiting.")
  Syslog.close

  # Return error status.
  exit error
end
