#
# Copyright (c) 2008--2014 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public License,
# version 2 (GPLv2). There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.
#
# Red Hat trademarks are not licensed under GPLv2. No permission is
# granted to use or replicate Red Hat trademarks that are incorporated
# in this software or its documentation.
#

use strict;

package Sniglets::Servers;

use Carp;
use POSIX;
use File::Spec;
use Data::Dumper;
use Date::Parse;

use PXT::Config ();
use PXT::Utils;
use PXT::HTML;


use RHN::Server;
use RHN::Set;
use RHN::Exception;
use RHN::Channel;
use RHN::ServerActions;
use RHN::Form;
use RHN::Form::Widget::CheckboxGroup;
use RHN::Form::Widget::Hidden;
use RHN::Form::Widget::Literal;
use RHN::Form::Widget::Select;
use RHN::Form::Widget::Submit;
use RHN::Form::ParsedForm;
use RHN::SatelliteCert;
use RHN::Kickstart::Session;

use Sniglets::Forms;
use Sniglets::HTML;
use Sniglets::ServerActions;

sub register_tags {
  my $class = shift;
  my $pxt = shift;
}

sub register_callbacks {
  my $class = shift;
  my $pxt = shift;

  $pxt->register_callback('rhn:remote-command-cb' => \&remote_command_cb);
  $pxt->register_callback('rhn:package-action-command-cb' => \&package_action_command_cb);
}

sub system_locked_info {
  my $user = shift;
  my $data = shift;

  my $ret = {};
  if ($data->{LOCKED}) {
    $ret->{icon} = 'system-locked';
    $ret->{status_str} = 'System locked';
    $ret->{status_class} = 'system-status-locked';
    $ret->{message} = 'more info';
  }
  return $ret;
}


# not a sniglet
sub system_status_info {
  my $user = shift;
  my $data = shift;

  my $sid = $data->{ID};
  my $ret;

  my $package_actions_count = RHN::Server->package_actions_count($sid);
  my $actions_count = RHN::Server->actions_count($sid);
  my $errata_count = $data->{SECURITY_ERRATA} + $data->{BUG_ERRATA} + $data->{ENHANCEMENT_ERRATA};

  $ret->{$_} = '' foreach (qw/image status_str status_class message link/);

  if (not $data->{IS_ENTITLED}) {
    $ret->{icon} = 'system-unentitled';
    $ret->{status_str} = 'System not entitled';
    $ret->{status_class} = 'system-status-unentitled';

    if ($user->is('org_admin')) {
      $ret->{message} = 'entitle it here';
      $ret->{link} = "/rhn/systems/details/Edit.do?sid=${sid}";
    }
  }
  elsif ($data->{LAST_CHECKIN_DAYS_AGO} > PXT::Config->get('system_checkin_threshold')) {
    $ret->{icon} = 'system-unknown';
    $ret->{status_str} = 'System not checking in with R H N';
    $ret->{status_class} = 'system-status-awol';
    $ret->{message} = 'more info';
  }
  elsif ($data->{KICKSTART_SESSION_ID}) {
    $ret->{icon} = 'system-kickstarting';
    $ret->{status_str} = 'Kickstart in progress';
    $ret->{status_class} = 'system-status-kickstart';
    $ret->{message} = 'view progress';
    $ret->{link} = "/rhn/systems/details/kickstart/SessionStatus.do?sid=${sid}";
  }
  elsif (not ($errata_count or $data->{OUTDATED_PACKAGES}) and not $package_actions_count) {
    $ret->{icon} = 'system-ok';
    $ret->{status_str} = 'System is up to date';
    $ret->{status_class} = 'system-status-up-to-date';
  }
  elsif ($errata_count and not RHN::Server->unscheduled_errata($sid, $user->id)) {
    $ret->{icon} = 'action-pending';
    $ret->{status_str} = 'All updates scheduled';
    $ret->{status_class} = 'system-status-updates-scheduled';
    $ret->{message} = 'view actions';
    $ret->{link} = "/rhn/systems/details/history/Pending.do?sid=${sid}";
  }
  elsif ($actions_count) {
    $ret->{icon} = 'action-pending';
    $ret->{status_class} = 'system-status-updates-scheduled';
    $ret->{status_str} = 'Actions scheduled';
    $ret->{message} = 'view actions';
    $ret->{link} = "/rhn/systems/details/history/Pending.do?sid=${sid}";
  }
  elsif ($data->{SECURITY_ERRATA}) {
    $ret->{icon} = 'system-crit';
    $ret->{status_str} = 'Critical updates available';
    $ret->{status_class} = 'system-status-critical-updates';
    $ret->{message} = 'update now';
    $ret->{link} = "/rhn/systems/details/ErrataConfirm.do?all=true&amp;sid=${sid}";
  }
  elsif ($data->{OUTDATED_PACKAGES}) {
    $ret->{icon} = 'system-warn';
    $ret->{status_str} = 'Updates available';
    $ret->{status_class} = 'system-status-updates';
    $ret->{message} = "more info";
    $ret->{link} = "/rhn/systems/details/packages/UpgradableList.do?sid=${sid}";
  }
  else {
    throw "logic error - system '$sid' does not have outdated packages, but is not up2date.";
  }

  return $ret;
}


sub system_monitoring_info {
  my $user = shift;
  my $data = shift;

  my $sid = $data->{ID};
  my $ret;

  $ret->{$_} = '' foreach (qw/image status_str status_class message link/);

  return $ret unless defined $data->{MONITORING_STATUS};

  if ($data->{MONITORING_STATUS} eq "CRITICAL") {
    $ret->{icon} = 'monitoring-crit';
    $ret->{status_str} = 'Critical probes';
    $ret->{system_link} = "/rhn/systems/details/probes/ProbesList.do?sid=${sid}";
  }
  elsif ($data->{MONITORING_STATUS} eq "WARNING") {
    $ret->{icon} = 'monitoring-warn';
    $ret->{status_str} = 'Warning probes';
    $ret->{system_link} = "/rhn/systems/details/probes/ProbesList.do?sid=${sid}";
  }
  elsif ($data->{MONITORING_STATUS} eq "UNKNOWN") {
    $ret->{icon} = 'monitoring-unknown';
    $ret->{status_str} = 'Unknown probes';
    $ret->{system_link} = "/rhn/systems/details/probes/ProbesList.do?sid=${sid}";
  }
  elsif ($data->{MONITORING_STATUS} eq "PENDING") {
    $ret->{icon} = 'monitoring-pending';
    $ret->{status_str} = 'Pending probes';
    $ret->{system_link} = "/rhn/systems/details/probes/ProbesList.do?sid=${sid}";
  }
  elsif ($data->{MONITORING_STATUS} eq "OK") {
    $ret->{icon} = 'monitoring-ok';
    $ret->{status_str} = 'OK';
    $ret->{system_link} = "/rhn/systems/details/probes/ProbesList.do?sid=${sid}";
  }

  return $ret;
}

my @user_server_prefs = ( { name => 'receive_notifications',
                            label => 'Receive Notifications of Updates/Errata' },
                          { name => 'include_in_daily_summary',
                            label => 'Include system in Daily Summary'},
                        );

my @server_prefs = ( { name => 'auto_update',
                       label => 'Automatic application of relevant errata' },
                   );

my %remote_command_modes = (
                            system_action => { type => 'standalone',
                                               location => 'sdc',
                                               verb => 'Install',
                                             },
                            package_install => { type => 'package',
                                                 location => 'sdc',
                                                 verb => 'Install',
                                               },
                            package_remove => { type => 'package',
                                                location => 'sdc',
                                                verb => 'Remove',
                                              },
                            ssm => { type => 'standalone',
                                     location => 'ssm',
                                     verb => 'Install',
                                   },
                            ssm_package_install => { type => 'package',
                                                     location => 'ssm',
                                                     verb => 'Install',
                                               },
                            ssm_package_upgrade => { type => 'package',
                                                     location => 'ssm',
                                                     verb => 'Upgrade',
                                               },
                            ssm_package_remove => { type => 'package',
                                                    location => 'ssm',
                                                    verb => 'Remove',
                                                  },
                           );

sub build_remote_command_form {
  my $pxt = shift;
  my %attr = @_;

  my $sid = $pxt->param('sid');
  my $mode = $attr{mode} || $pxt->dirty_param('mode') || 'system_action';

  my $form = new RHN::Form::ParsedForm(name => 'Remote Command',
                                       label => 'remote_command_form',
                                       action => $attr{action},
                                      );

  if ($remote_command_modes{$mode}->{type} eq 'package') {
    $form->add_widget(radio_group => { name => 'Run',
                                       label => 'run_script',
                                       value => 'before',
                                       options => [ { value => 'before', label => 'Before package action' },
                                                    { value => 'after', label => 'After package action' },
                                                  ],
                                     });
  }

  $form->add_widget(text => { name => 'Run as user',
                              label => 'username',
                              default => 'root',
                              maxlength => 32,
                              requires => { response => 1 },
                            } );

  $form->add_widget(text => { name => 'Run as group',
                              label => 'group',
                              default => 'root',
                              maxlength => 32,
                              requires => { response => 1 },
                            } );

  $form->add_widget(text => { name => 'Timeout (seconds)',
                              label => 'timeout',
                              default => '600',
                              mexlenth => 16,
                              size => 6,
                            } );

  $form->add_widget(textarea => { name => 'Script',
                                  label => 'script',
                                  rows => 8,
                                  cols => 80,
                                  wrap => 'off',
                                  default => "#!/bin/sh\n",
                                  requires => { response => 1 },
                                });

  $form->add_widget(hidden => { label => 'mode', value => $mode });

  my $sched_img = PXT::HTML->img(-src => '/img/rhn-icon-schedule.gif', -alt => 'Date Selection');
  my $sched_widget =
    new RHN::Form::Widget::Literal(label => 'pickbox',
                                   name => 'Schedule no sooner than',
                                   value => $sched_img . Sniglets::ServerActions::date_pickbox($pxt));

  if ($remote_command_modes{$mode}->{type} eq 'package'
      and $remote_command_modes{$mode}->{location} eq 'sdc') {
    die "No system id" unless $sid;

    $form->add_widget(hidden => { label => 'set_label', value => $pxt->dirty_param('set_label') });

    $form->add_widget(hidden => { label => 'pxt:trap', value => 'rhn:package-action-command-cb' });
    $form->add_widget(submit => { label => 'Schedule Package Install', name => 'schedule_remote_command' });
  }
  elsif ($remote_command_modes{$mode}->{type} eq 'package'
         and $remote_command_modes{$mode}->{location} eq 'ssm') {
    $form->add_widget(hidden => { label => 'pxt:trap', value => 'rhn:package-action-command-cb' });

    $form->add_widget($sched_widget);

    $form->add_widget(submit => { label => 'Schedule Remote Command', name => 'schedule_remote_command' });
  }
  elsif ($remote_command_modes{$mode}->{type} eq 'standalone'
         and $remote_command_modes{$mode}->{location} eq 'sdc') {
    die "No system id" unless $sid;

    $form->add_widget(hidden => { label => 'pxt:trap', value => 'rhn:remote-command-cb' });
    $form->add_widget($sched_widget);

    $form->add_widget(submit => { label => 'Schedule Remote Command', name => 'schedule_remote_command' });
  }
  elsif ($remote_command_modes{$mode}->{type} eq 'standalone'
         and $remote_command_modes{$mode}->{location} eq 'ssm') {

    #$form->add_widget(hidden => { label => 'pxt:trap', value => 'rhn:remote-command-ssm-cb' });
    $form->add_widget($sched_widget);

    $form->add_widget(submit => { label => 'Schedule Remote Command', name => 'schedule_remote_command' });
  }
  else {
    throw "Unknown mode: '$mode'\n";
  }

  if ($mode eq 'ssm_package_install') {
    $form->add_widget(hidden => { label => 'sscd_confirm_package_installations', value => 1 });
  }
  elsif ($mode eq 'ssm_package_upgrade') {
    $form->add_widget(hidden => { label => 'sscd_confirm_package_upgrades', value => 1 });
  }
  elsif ($mode eq 'ssm_package_remove') {
    $form->add_widget(hidden => { label => 'sscd_confirm_package_removals', value => 1 });
  }

  if ($sid) {
    $form->add_widget(hidden => { label => 'sid', value => $sid });
  }

  my $cid = $pxt->param('cid');

  if ($cid) {
    $form->add_widget(hidden => {label => 'cid', value => $cid});
  }

  return $form;
}

sub remote_command_cb {
  my $pxt = shift;

  my $pform = build_remote_command_form($pxt);
  my $form = $pform->prepare_response;
  undef $pform;

  my $errors = Sniglets::Forms::load_params($pxt, $form);

  if (@{$errors}) {
    foreach my $error (@{$errors}) {
      $pxt->push_message(local_alert => $error);
    }
    return;
  }

  my $sid = $form->param('sid');
  my $username = $form->param('username');
  my $group = $form->param('group');
  my $script = $form->param('script');
  my $timeout = $form->param('timeout');

  my $earliest_date = Sniglets::ServerActions->parse_date_pickbox($pxt);

  my $action_id = RHN::Scheduler->schedule_remote_command(-org_id => $pxt->user->org_id,
                                                          -user_id => $pxt->user->id,
                                                          -earliest => $earliest_date,
                                                          -server_id => $sid,
                                                          -action_name => undef,
                                                          -script => $script,
                                                          -username => $username,
                                                          -group => $group,
                                                          -timeout => $timeout,
                                                         );

  my $system = RHN::Server->lookup(-id => $sid);

#   $pxt->push_message(site_info => sprintf(<<EOQ, $sid, $action_id, $system->name));
# Remote command <a href="/rhn/systems/details/history/Event.do?sid=%d&amp;aid=%d">scheduled</a> for <strong>%s</strong>.
# EOQ

  $pxt->redirect("/rhn/systems/details/Overview.do?sid=$sid&message=system.remotecommand.scheduled&messagep1=$sid&messagep2=$action_id&messagep3=" . $system->name);
}

sub package_action_command_cb {
  my $pxt = shift;

  my $pform = build_remote_command_form($pxt);
  my $form = $pform->prepare_response;
  undef $pform;

  my $errors = Sniglets::Forms::load_params($pxt, $form);

  if (@{$errors}) {
    foreach my $error (@{$errors}) {
      $pxt->push_message(local_alert => $error);
    }
    return;
  }

  my $sid = $form->param('sid');
  my $username = $form->param('username');
  my $group = $form->param('group');
  my $script = $form->param('script');
  my $order = $form->param('run_script');
  my $timeout = $form->param('timeout');
  my $mode = $form->param('mode');
  my $system_set;

  my $earliest_date = Sniglets::ServerActions->parse_date_pickbox($pxt);

  if ($remote_command_modes{$mode}->{location} eq 'ssm') {
    $system_set = RHN::Set->lookup(-label => 'system_list', -uid => $pxt->user->id);
  }

  my @actions;
  my $actions_by_sid;

  if ($mode eq 'package_install') {
    @actions = Sniglets::ListView::PackageList::install_packages_cb($pxt);
  }
  elsif ($mode eq 'package_remove') {
    @actions = Sniglets::ListView::PackageList::remove_packages_cb($pxt);
  }
  elsif ($mode eq 'ssm_package_install') {
    @actions = Sniglets::Packages::sscd_confirm_package_installations_cb($pxt);
  }
  elsif ($mode eq 'ssm_package_upgrade') {
    $actions_by_sid = Sniglets::Packages::sscd_confirm_package_upgrades_cb($pxt);
  }
  elsif ($mode eq 'ssm_package_remove') {
    @actions = Sniglets::Packages::sscd_confirm_package_removals_cb($pxt);
  }
  else {
    throw "Invalid mode: $mode";
  }

  return unless (@actions or $actions_by_sid);

  my $cmd_aid;

  if (@actions) {
    $cmd_aid = RHN::Scheduler->schedule_remote_command(-org_id => $pxt->user->org_id,
                                                          -user_id => $pxt->user->id,
                                                          -earliest => $earliest_date,
                                                          -server_id => $sid,
                                                          -server_set => $system_set,
                                                          -action_name => undef,
                                                          -script => $script,
                                                          -username => $username,
                                                          -group => $group,
                                                          -timeout => $timeout,
                                                         );

    schedule_action_prereq($order, $cmd_aid, @actions);

  }
  else {
    foreach my $server_id (keys %{$actions_by_sid}) {
      $cmd_aid = RHN::Scheduler->schedule_remote_command(-org_id => $pxt->user->org_id,
                                                            -user_id => $pxt->user->id,
                                                            -earliest => $earliest_date,
                                                            -server_id => $server_id,
                                                            -action_name => undef,
                                                            -script => $script,
                                                            -username => $username,
                                                            -group => $group,
                                                            -timeout => $timeout,
                                                           );
      schedule_action_prereq($order, $cmd_aid, @{$actions_by_sid->{$server_id}});
    }
  }

  my $verb = $remote_command_modes{$mode}->{verb};

  $pxt->push_message(site_info =>
                     "The remote command action was scheduled to run <strong>$order</strong> the package $verb action" . (scalar @actions == 1 ? '' : 's') . ".");

  if ($remote_command_modes{$mode}->{location} eq 'ssm') {
    $pxt->redirect('/network/systems/ssm/packages/index.pxt');
  }

  return;
}

sub schedule_action_prereq {
  my $order = shift;
  my $target_aid = shift;
  my @actions = @_;

  if ($order eq 'before') {
    $actions[0]->prerequisite($target_aid);
    $actions[0]->commit;
  }
  elsif ($order eq 'after') {
    my $target_action = RHN::Action->lookup(-id => $target_aid);
    $target_action->prerequisite($actions[-1]->id);
    $target_action->commit;
  }
  else {
    throw "Unknown order: '$order'."
  }

  return;
}

1;
