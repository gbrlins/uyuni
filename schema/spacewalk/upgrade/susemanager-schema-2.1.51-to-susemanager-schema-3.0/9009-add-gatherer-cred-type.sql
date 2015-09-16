--
-- Copyright (c) 2014 Novell
--
-- This software is licensed to you under the GNU General Public License,
-- version 2 (GPLv2). There is NO WARRANTY for this software, express or
-- implied, including the implied warranties of MERCHANTABILITY or FITNESS
-- FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
-- along with this software; if not, see
-- http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.
--
-- Red Hat trademarks are not licensed under GPLv2. No permission is
-- granted to use or replicate Red Hat trademarks that are incorporated
-- in this software or its documentation.
--

insert into suseCredentialsType (id, label, name) (
  select sequence_nextval('suse_credtype_id_seq'), 'vhm', 'Virtual Host Manager'
    from dual
   where not exists (
           select 1
             from suseCredentialsType
            where label = 'vhm'
  )
);
