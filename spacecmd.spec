%define rhnroot %{_datadir}/rhn

Name:		spacecmd
Version:	0.2
Release:	1%{?dist}
Summary:	CLI to Spacewalk and RHN Satellite Server

Group:		Applications/System
License:	GPL
URL:		http://github.com/aparsons/spacecmd
Source0:	%{name}-%{version}.tar.gz
BuildRoot:	%(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
BuildArch:	noarch

Requires:	python >= 2.4


%description
Provides a command line interface to Spacewalk, including 
extensive tab-completion features and SSM (system set manager).


%prep
%setup -q


%build


%install
rm -rf %{buildroot}

mkdir -p %{buildroot}/%{_bindir}
install -m0755 spacecmd %{buildroot}/%{_bindir}/

mkdir -p %{buildroot}/%{rhnroot}/spacecmd
install -m0644 SpacewalkShell.py %{buildroot}/%{rhnroot}/spacecmd/

touch %{buildroot}/%{rhnroot}/spacecmd/__init__.py
chmod 0644 %{buildroot}/%{rhnroot}/spacecmd/__init__.py


%clean
rm -rf %{buildroot}


%files
%defattr(-,root,root,-)
%doc README COPYING
%{_bindir}/spacecmd
%dir %{rhnroot}/spacecmd
%{rhnroot}/spacecmd/*


%changelog
* Mon Jun 21 2010 Aron Parsons <aparsons@redhat.com> - 0.2-1
- version bump

* Mon Jun 21 2010 Aron Parsons <aparsons@redhat.com> - 0.1-4
- added distribution headings
- added a copy of the GPL

* Thu Apr 29 2010 Aron Parsons <aparsons@redhat.com> - 0.1-3
- just touch __init__.py, no reason to version control an empty file

* Wed Apr 28 2010 Aron Parsons <aparsons@redhat.com> - 0.1-2
- moved SpacewalkShell.py to /usr/share/rhn/spacecmd

* Tue Apr 27 2010 Paul Morgan <pmorgan@redhat.com> - 0.1-1
- initial packaging
