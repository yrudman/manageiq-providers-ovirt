require 'manageiq/providers/ovirt/legacy/event_monitor'

class ManageIQ::Providers::Redhat::InfraManager::EventCatcher::Runner < ManageIQ::Providers::BaseManager::EventCatcher::Runner
  def event_monitor_handle
    @event_monitor_handle ||= ManageIQ::Providers::Ovirt::Legacy::EventMonitor.new(event_monitor_options)
  end

  def event_monitor_options
    {
      :server     => @ems.hostname,
      :port       => @ems.port.blank? ? nil : @ems.port.to_i,
      :username   => @ems.authentication_userid,
      :password   => @ems.authentication_password,
      :verify_ssl => false
    }
  end

  def reset_event_monitor_handle
    @event_monitor_handle = nil
  end

  def stop_event_monitor
    @event_monitor_handle.stop unless @event_monitor_handle.nil?
  rescue Exception => err
    _log.warn("#{log_prefix} Event Monitor Stop errored because [#{err.message}]")
    _log.warn("#{log_prefix} Error details: [#{err.details}]")
    _log.log_backtrace(err)
  ensure
    reset_event_monitor_handle
  end

  def monitor_events
    event_monitor_handle.start
    event_monitor_handle.each_batch do |events|
      event_monitor_running
      @queue.enq events
      sleep_poll_normal
    end
  ensure
    reset_event_monitor_handle
  end

  def queue_event(event)
    _log.info "#{log_prefix} Caught event [#{event[:name]}]"
    event_hash = ManageIQ::Providers::Redhat::InfraManager::EventParser.event_to_hash(event.to_hash, @cfg[:ems_id])
    EmsEvent.add_queue('add', @cfg[:ems_id], event_hash)
  end

  def filtered?(event)
    filtered_events.include?(event[:name])
  end
end
