create or replace package xut 
is
/*-----------------------------------------------------------------------------
It is just a little bit of awesome that I have cooked up.  This will run all the 
test methods in  a package and will run a setup and a teartdown method before and 
after each test method.  The super neat thing is that you don't make the test
methods public.  the run_packag_tests method will make all test methods public,
then run them, then put the package back to the way it found it.  Super neat.

The methods that can be setup are defined in the globals below.  These are global
so that the values can be changed at runtime to suit any environment's naming
conventions.  The names of the procedures must match the values of the globals
identically.
    *  g_pretest_setup method runs ONCE before anything else is run.
    *  g_post_test_teardown_method runs ONCE after everything has been run.
    *  g_setup_method runs before EACH test.
    *  g_teardown_method runs after EACH test.
        
Tests will be called in the order they are declared in the body.

Test Package Body template.
<code>
    
    --runs before ANY tests are run
    procedure testprerunsetup is
    begin
        null;
    end;
    
    --runs ater ALL tests have run
    procedure testpostrunteardown is
    begin
        null;
    end;
    
    --runs after each test.
    procedure testteardown is
    begin
        --no changes saved during tests
        rollback;
    end;
    
    --runs before each test.
    procedure testsetup is
    begin
        null;
    end;

--!-------------------
--!These will print as a heading
--!-------------------

    --#This will print before the test name, so you don't have to decifer what 
    --#a 30 character test name really means.  Though you should still try to 
    --#be descriptive in your test name.
    procedure test_something
    is
    begin
        xut.assert(false, 'write a test');
    end;    
</code>
-----------------------------------------------------------------------------*/
    type t_unit_test is record (test_name varchar2(2000),
                                comments varchar2(2000),
                                heading varchar2(2000), 
                                line_number number);
    type t_unit_tests is table of t_unit_test index by binary_integer;

----------------------
--Log Level Constants
----------------------
    --Show only failure and summary information
    LOG_LEVEL_LOW       constant number := 1;
    --Show all tests that are run and any information that is printed
    LOG_LEVEL_HIGH      constant number := 2;
    --Show assertion passed messages as well.
    LOG_LEVEL_HIGHER   constant number := 3;
    LOG_LEVEL_SUPER     constant number := 4;    
----------------------
--Assertions
----------------------
    ---------------------------------------------------------------------------
    --Assert in_bool is true.  Log failure if not.
    ---------------------------------------------------------------------------    
    procedure assert(in_bool in boolean, in_msg in varchar2);
    
    ---------------------------------------------------------------------------
    --Assert in_got == in_expected is true.  Log failure if not.
    ---------------------------------------------------------------------------    
    procedure assert(in_got in number, in_expected in number, in_msg in varchar2);
    
    ---------------------------------------------------------------------------
    --Assert in_got == in_expected is true.  Log failure if not.
    ---------------------------------------------------------------------------    
    procedure assert(in_got in varchar2, in_expected in varchar2, in_msg in varchar2);
    
    ---------------------------------------------------------------------------
    --Assert in_got == in_expected is true.  Log failure if not.
    ---------------------------------------------------------------------------    
    procedure assert_eq(in_got in number, in_expected in number, in_msg in varchar2);
    
    ---------------------------------------------------------------------------
    --Assert in_got == in_expected is true.  Log failure if not.
    ---------------------------------------------------------------------------    
    procedure assert_eq(in_got in varchar2, in_expected in varchar2, in_msg in varchar2);
    
    ---------------------------------------------------------------------------
    --Assert in_got != in_expected is true.  Log failure if not.
    ---------------------------------------------------------------------------    
    procedure assert_ne(in_got in varchar2, in_expected in varchar2, in_msg in varchar2);
    
    ---------------------------------------------------------------------------    
    --Assert in_got > in_exptected.  Log failure if not.
    ---------------------------------------------------------------------------        
    procedure assert_gt(in_got in number, in_threshold in varchar, in_msg in varchar2);
    
    ---------------------------------------------------------------------------        
    --Marks the test it is called in as expected to fail with the passed in 
    --error number.  If the test errors with the expected number then it
    --is considered to pass, if not it will mark it as failed.
    --
    --This is an alternative approach than using assert_errors and 
    --assert_no_error.  With this approach, you don't have to pass in dynamic
    --sql to execute.
    --
    --Call this BEFORE doing any code that could error.
    ---------------------------------------------------------------------------        
    procedure set_expected_error_sqlcode(in_sqlcode in number);
    
    ---------------------------------------------------------------------------        
    --Mark test as pending.
    ---------------------------------------------------------------------------            
    procedure pending(in_msg in varchar2 default null);

-------------------
--Utility
-------------------
    ---------------------------------------------------------------------------
    --print output with an indent.  helpful when debugging tests, but should
    --not be used excessively.
    ---------------------------------------------------------------------------            
    procedure print(in_text in varchar2, in_indent number default 0);
    --convenience method
    procedure p(in_text in varchar2, in_indent number default 0);
    
    procedure print_settings;
-------------------
--Run Tests
-------------------
    ---------------------------------------------------------------------------        
    --Runs all test methods in the passed in package.  If the test name is 
    --specified then only that one test is run.
    ---------------------------------------------------------------------------        
    procedure test_package(in_pkg_name in varchar2, in_test_name in varchar2 default NULL);
    
    ---------------------------------------------------------------------------        
    --Runs all test packages that exist for the specified user.
    ---------------------------------------------------------------------------            
    procedure test_user(in_user in varchar2);

-------------------
--Accessors
-------------------
    ---------------------------------------------------------------------------            
    --Get the number of tests that were ran
    ---------------------------------------------------------------------------            
    function get_test_count return number;
    ---------------------------------------------------------------------------
    --Get the number of tests that have been marked pending
    ---------------------------------------------------------------------------
    function get_pending_count return number;
    ---------------------------------------------------------------------------
    --Get the number of tests that failed.
    ---------------------------------------------------------------------------
    function get_fail_count return number;
    ---------------------------------------------------------------------------
    --Get the prefix for all test packages as defined by the constant
    ---------------------------------------------------------------------------
    function get_package_prefix return varchar2;    
    ---------------------------------------------------------------------------
    --get the prefix for all test methods
    ---------------------------------------------------------------------------
    function get_method_prefix return varchar2;    
    ---------------------------------------------------------------------------
    --One of the xut.LOG_LEVEL_* constant values.  See the constant defiinition
    --for more information about the values.
    ---------------------------------------------------------------------------
    procedure set_log_level(in_log_level in number);
    ---------------------------------------------------------------------------
    --get the name of the currently running test.  Mostly used for debugging
    --this package.
    ---------------------------------------------------------------------------
    function get_current_test_name return varchar2;    
    ---------------------------------------------------------------------------
    --get the comments that procede the current test with the --# format
    ---------------------------------------------------------------------------
    function get_current_test_comment return varchar2;    
end xut;
/
create or replace package body xut is    
    g_log_level number := LOG_LEVEL_HIGH;
    ASSERT_PASS_MSG         constant varchar2(20) := 'YES';
    --indent value to put output under a test.
    TEST_INDENT             constant number := 2;
    CR constant varchar2(1) := chr(10);

    --Name of the current package
    g_cur_pkg               varchar2(100);              
    --currently running test
    g_cur_test_name     varchar2(100);  
    --The unit test we are currently on
    g_cur_unit          number := 0;
    --Number of tests that are pending.
    g_pending_count     number := 0;        
    --Used to prevent the unit from being printed too many times.
    g_has_printed_unit      boolean := false;
    --Number of tests that have occurred (asserts and such)
    g_test_count            number := 0;                
    --total number of failures (asserts and such)
    g_fail_count        number := 0;    
    --Array of the original package spec
    g_old_pkg_spec          xu_datatype.t_vc2k_array;   
    --Array of the test methods pulled from body
    g_private_test_methods  t_unit_tests;   
    --Expected error number.  Set by set_exptected_error_sqlcode
    --and cleared after each test.
    g_expected_sqlcode      number;
    --Same as g_expected_sqlcode but a specific exception instead
    --of a number;
    g_expected_exception    exception;
    --method names and object prefix vars
    g_pretest_setup_method       varchar2(100) := 'TESTPRERUNSETUP';
    g_post_test_teardown_method  varchar2(100) := 'TESTPOSTRUNTEARDOWN';  
    g_teardown_method            varchar2(100) := 'TESTTEARDOWN';
    g_setup_method               varchar2(100) := 'TESTSETUP';        
    g_test_package_prefix        varchar2(10) := 'TEST_';
    g_test_method_prefix         varchar2(10) := 'TEST_';
    g_test_method_name_tag       varchar2(10) := '--#';
    g_test_heading_tag           varchar2(10) := '--!';
    
------------
--Private
------------
    -----------------------------------------------------------------------------
    --Prints the unit test name if it hasn't been printed already.  Multiple 
    --places during the testing of a method may try to print the unit test name.
    --This ensures that it does not happen more than once.
    -----------------------------------------------------------------------------    
    procedure print_unit_test_name is
        l_out       varchar2(4000) := '';
    begin
        if (not g_has_printed_unit and g_cur_unit <> 0) then            
            if(g_private_test_methods(g_cur_unit).heading is not null)then
                l_out := g_private_test_methods(g_cur_unit).heading;
            end if;
            
            l_out := l_out||'* ';
            if(g_private_test_methods(g_cur_unit).comments is not null)then 
                l_out := l_out ||trim(g_private_test_methods(g_cur_unit).comments)||
                         ' ['||g_private_test_methods(g_cur_unit).test_name||']';
            else
                l_out := l_out ||g_private_test_methods(g_cur_unit).test_name;
            end if;
            dbms_output.put_line(l_out);
            g_has_printed_unit := true;
        end if;
    end;
    
    -----------------------------------------------------------------------------
    --Uses 'p' to output the text based on what the current log level is set to.
    --In most cases, this should be used instead of 'p' so that the display of 
    --information can be toggled.
    -----------------------------------------------------------------------------    
    procedure log(in_text in varchar2, in_indent number, in_log_level in number default -1)
    is
    begin
        if(in_log_level <= g_log_level)then
            p(in_text, in_indent);
        end if;
    end;

    -----------------------------------------------------------------------------
    --Fail a test and display the text.  Used by asserts etc.
    -----------------------------------------------------------------------------  
    procedure fail(in_text in varchar2) is
    begin
        g_fail_count := g_fail_count + 1;
        log('FAILED:  ' || in_text, TEST_INDENT);
    end;

    -----------------------------------------------------------------------------
    --Run the passed in method and wrap it with an exception handler.  If it fails
    --with a code other than 
    -----------------------------------------------------------------------------    
    procedure run_method(in_method in varchar2) is
    begin
        execute immediate 'begin ' || in_method || '; end;';
        if(g_expected_sqlcode is not null)then
            assert(false, 'The expected error ('||g_expected_sqlcode||') did not occur.');
        end if;
    exception
        when others then
            if(g_expected_sqlcode is not null)then
                if(g_expected_sqlcode <> sqlcode)then
                    fail('Unexpected error (' || sqlcode || '):  ' || sqlerrm||chr(13)||
                          dbms_utility.format_error_backtrace);
                else
                    assert(true, 'Expected error caught.');
                end if;
            else
                --4061 is existing state of package has been discarded.  Was an attempt to
                --ignore this error, but should probably be removed and all tests should
                --alwasy be run in a 'testing' window in PL/SQL Developer.
                if(sqlcode <> -4061)then
                    fail('Unexpected error (' || sqlcode || '):  ' || sqlerrm||chr(13)||
                          dbms_utility.format_error_backtrace);
                else
                    raise;
                end if;
            end if;
    end;

    -----------------------------------------------------------------------------
    --Runs the passed in method but does not trap any expcetions thrown by the
    --method.
    -----------------------------------------------------------------------------    
    procedure run_method_no_trap(in_method in varchar2) is
    begin
        execute immediate 'begin ' || in_method || '; end;';
    exception
        when others then
            dbms_output.put_line('Error running:  ' || in_method);
            dbms_output.put_line(sqlerrm);
            raise;
    end;

    -----------------------------------------------------------------------------
    --Checks to see if the passed in method is public in the passed in package.
    -----------------------------------------------------------------------------    
    function method_exists(in_pkg in varchar2, in_method in varchar2) return boolean is
        l_count number;
    begin
        select count(1)
          into l_count
          from all_procedures
         where object_name = upper(in_pkg)
           and procedure_name = upper(in_method);
    
        return l_count > 0;
    end;

    -----------------------------------------------------------------------------
    --Puts the original package specification back and recompiles the package.
    -----------------------------------------------------------------------------    
    procedure put_old_spec_back is
        l_old_spec clob;
    begin
    
        for i in 1 .. g_old_pkg_spec.count loop
            l_old_spec := l_old_spec || g_old_pkg_spec(i);
        end loop;
    
        execute immediate l_old_spec;
        execute immediate 'ALTER PACKAGE ' || g_cur_pkg || ' COMPILE';
        execute immediate 'ALTER PACKAGE ' || g_cur_pkg || ' COMPILE BODY';
    exception
        when others then
            p('ERROR!!  putting spec back:  ' || sqlerrm);
            P(l_old_spec);
            p('RECOMPILE THE PACKAGE SPEC MANUALLY!!');
    end;

    -----------------------------------------------------------------------------
    --intitalizes g_cur_pkg and the g_old_pkg_spec array.
    -----------------------------------------------------------------------------    
    procedure set_old_pkg_spec(in_pkg in varchar2) is
        --Gets a package spec    
        cursor c_pkg_spec(in_pkg in varchar2) is
            select text
              from all_source
             where name = upper(in_pkg)
               and type = 'PACKAGE'
             order by line;
    begin
        g_cur_pkg := upper(in_pkg);
        open c_pkg_spec(in_pkg);
        fetch c_pkg_spec bulk collect
            into g_old_pkg_spec;
        close c_pkg_spec;
        
        g_old_pkg_spec(1) := 'create or replace package ' || in_pkg || ' is' || CR;
    end;

    -----------------------------------------------------------------------------
    --Used to get the method name out of a procedure's decleration in the body.
    --Could probably be done easier with some regex.
    -----------------------------------------------------------------------------
    function parse_out_method_name(in_line_of_code in varchar2)return varchar2
    is
        l_return        varchar2(200);
        l_loc           number;
    begin
        l_return := lower(in_line_of_code);

        --strip off everything before, and including, the word "procedure"
        l_loc := instr(l_return, 'procedure'); 
        if(l_loc > 0)then
            l_return := trim(substr(l_return, l_loc + length('procedure')));
        end if;

        --Strip off any comments that might be at the end.    
        l_loc := instr(l_return, '--');
        if(l_loc > 0)then
            l_return := trim(substr(l_return, 1, l_loc -1));
        end if;

        --The next space would come after the end of the procedure name(if one
        --exists).  Strip everything off after that.
        l_loc := instr(l_return, ' ');
        if(l_loc > 0)then
            l_return := trim(substr(l_Return, 1, l_loc));
        end if;
        
        --Strip off any other whitespace such as carriage returns or 
        --anything missed before.
        l_return := regexp_replace(l_return, '[[:space:]]*','');
        
        return l_return;
    end;    
    -----------------------------------------------------------------------------
    --Fills the g_private_test_method array of all the private methods in the
    --package body that match either the test patter or are the same as the
    --setup/teardown method names.
    -----------------------------------------------------------------------------    
    procedure set_test_methods_from_body(in_pkg in varchar2) is
        --gets all testing methods out of the body.
        cursor c_private_test_methods(in_pkg in varchar2) is
            select text, line
              from all_source
             where name = upper(in_pkg)
               and type = 'PACKAGE BODY'
               and (regexp_like(upper(text), '\s*PROCEDURE\s*'|| g_test_method_prefix||'\w*', 'i') or
                   regexp_like(upper(text), '\s*PROCEDURE\s*' || g_setup_method, 'i') or
                   regexp_like(upper(text), '\s*PROCEDURE\s*' || g_teardown_method, 'i') or
                   regexp_like(upper(text), '\s*PROCEDURE\s*' || g_pretest_setup_method, 'i') or
                   regexp_like(upper(text), '\s*PROCEDURE\s*' || g_post_test_teardown_method, 'i'))
             order by line;
        i   number;
        l_last_line number := 1;
        
        --TODO Currently goes to the start of the previous method.  Should only go to the end.                  
        function get_prefixed_comments(in_prefix in varchar2,
                                       in_method_line_number in number, 
                                       in_prev_method_line_number in number) return varchar2
        is
            cursor comments is
                select * 
                  from all_source 
                 where name = upper(in_pkg)
                   and type = 'PACKAGE BODY'
                   and line between in_prev_method_line_number and in_method_line_number
                   and text like ('%'||in_prefix||'%');
            
            l_comments      varchar2(4000);
            l_line          varchar2(4000);
        begin
            for rec in comments loop                
                l_line := trim(substr(rec.text, instr(rec.text, in_prefix) + length(in_prefix)));                
                l_comments := l_comments || l_line;
            end loop;                        
            return trim(l_comments);
        end;
        
   
    begin
        l_last_line := 1;
        i := 1;
        for rec in c_private_test_methods(in_pkg) loop            
            g_private_test_methods(i).test_name := parse_out_method_name(rec.text);
            g_private_test_methods(i).line_number := rec.line;
            g_private_test_methods(i).comments := get_prefixed_comments(g_test_method_name_tag, rec.line, l_last_line);
            g_private_test_methods(i).comments := 
                trim(replace(replace(g_private_test_methods(i).comments, chr(13), ' '), chr(10), ''));
            g_private_test_methods(i).heading := get_prefixed_comments(g_test_heading_tag, rec.line, l_last_line);
            i := i + 1;
            l_last_line := rec.line;

        end loop;
    end;

    -----------------------------------------------------------------------------
    --Compiles a new version of the package specification that includes all the
    --test and setup/teardown methods that are defined in the package body.  This
    --will make all the testing related methods public so that they can be 
    --executed.
    -----------------------------------------------------------------------------    
    procedure make_tests_public(in_pkg in varchar2) is
        l_new_spec       clob;
        l_old_spec_index number := 1;
        l_end_pkg_index  number := -1;
    begin
        set_old_pkg_spec(in_pkg);
        set_test_methods_from_body(in_pkg);
    
        --start the package with the public methods that already exist, leave
        --the last line off.
        l_old_spec_index := 1;
        while (l_old_spec_index <= g_old_pkg_spec.count and l_end_pkg_index = -1) loop
            if (regexp_like(g_old_pkg_spec(l_old_spec_index), '\s*end;\s*', 'i') or
               regexp_like(g_old_pkg_spec(l_old_spec_index), '\s*end\s*' || in_pkg || '\s*;\s*', 'i')) then
                l_end_pkg_index := l_old_spec_index;
            else
                l_new_spec       := l_new_spec || g_old_pkg_spec(l_old_spec_index);
                l_old_spec_index := l_old_spec_index + 1;
            end if;
        end loop;
    
        if (l_end_pkg_index = -1) then
            raise_application_error(-20001, 'Could not find end of spec.');
        end if;
    
        --Add in all the private test methods found
        for i in 1 .. g_private_test_methods.count  loop
            l_new_spec := l_new_spec ||'PROCEDURE '|| g_private_test_methods(i).test_name||';'||CR;
        end loop;
    
        --put the end line on
        l_new_spec := l_new_spec || g_old_pkg_spec(l_end_pkg_index) || CR;
    
        execute immediate l_new_spec;
    exception
        when others then
            p(l_new_spec);
            p('COULD NOT COMPILE SPEC WITH TESTS.');
            p('  Testing aborted.');
            p(sqlerrm);
            dbms_output.put_line(dbms_utility.format_error_backtrace);
            p(l_new_spec);
            put_old_spec_back;
            raise;
    end;

    -----------------------------------------------------------------------------
    --Run before testing all methods in test_package
    -----------------------------------------------------------------------------    
    procedure init_test(in_test_name in varchar2) is
    begin
        g_cur_test_name    := in_test_name;
        g_fail_count       := 0;
        g_test_count       := 0;
        g_pending_count    := 0;
        g_cur_unit         := 0;
        g_has_printed_unit := false;
    
        p('Test:  ' || g_cur_test_name);
    end;

    -----------------------------------------------------------------------------
    --Sets all globals related to the current unit test being run.
    -----------------------------------------------------------------------------    
    procedure set_unit(in_unit in number) is
    begin
        g_cur_unit         := in_unit;
        g_has_printed_unit := false;
    end;

    -----------------------------------------------------------------------------
    --Prints out summary info for when a test run has finished.
    -----------------------------------------------------------------------------    
    procedure end_test is
    begin
        --set this to true always since we are not in a unit test
        --anymore and we don't want the last test ran to have the
        --name printed.
        g_has_printed_unit := true;
    
        if (g_pending_count > 0) then
            p('PENDING:  ' || g_pending_count);
        end if;
    
        if (g_fail_count > 0) then
            p('FAILURE:  ' || g_fail_count || ' of ' || g_test_count || ' failed.');
        else
            p('SUCCESS:  All ' || g_test_count || ' tests passed.');
        end if;
    end;
------------
--Public Utilities
------------
    -----------------------------------------------------------------------------
    --See spec
    -----------------------------------------------------------------------------    
    function get_n_length_string(in_n in number) return varchar2 is
    begin
        return lpad('a', in_n, 'a');
    end;

    -----------------------------------------------------------------------------
    --Prints the passed in text indented to the optional indent level.  If the unit
    --test name has not yet been printed then this will print it.
    -----------------------------------------------------------------------------    
    procedure p(in_text in varchar2, in_indent number default 0) is
        l_indent varchar2(100) := '';    
    begin
        print_unit_test_name;
        
        if (in_indent > 0) then
            l_indent := lpad(' ', in_indent * 2, '  ');
        end if;
        dbms_output.put_line(l_indent || in_text);
    end;

    -----------------------------------------------------------------------------
    --renamed to p, kept in case it was being used.
    -----------------------------------------------------------------------------    
    procedure print(in_text in varchar2, in_indent number default 0) is
    begin
        p(in_text, in_indent);
    end;
    
    procedure print_settings is
        l_pad       number := 33;
    begin
        p('Settings');
        p(rpad('Pre-run setup method name:  ', l_pad)||g_pretest_setup_method, 2);
        p(rpad('Post-run teardown meothd name:', l_pad)||g_post_test_teardown_method, 2);
        p(rpad('Pre-test setup method name:', l_pad)||g_setup_method, 2);
        p(rpad('Post-test teardown method name:', l_pad)||g_teardown_method, 2);        
        p(rpad('Test method prefix:', l_pad)||g_test_method_prefix, 2);
        p(rpad('Test method name <tag>:', l_pad)||g_test_method_name_tag, 2);
        p(rpad('Test package prefix:', l_pad)||g_test_package_prefix, 2);
    end;

    -----------------------------------------------------------------------------
    --Runs all tests that are in the g_private_test_methods array.  This will
    --run the pre-run and post-run methods before and after all the tests as
    --well as the setup and teardown methods before and after each test.
    --
    --Takes an optional single test name that will cause this to run just
    --the one test as if it were the only test in the package.
    -----------------------------------------------------------------------------    
    procedure run_tests_as_a_test_package(in_package_name in varchar2, in_test_name varchar2 default null)
    is
        l_teardown_exists boolean := false;
        l_setup_exists    boolean := false;    
    begin
        --Check for pre-run setup method
        if (method_exists(in_package_name, g_pretest_setup_method)) then
            log('[Pre-run setup]', 0, LOG_LEVEL_HIGHER);
            run_method_no_trap(in_package_name || '.' || g_pretest_setup_method);
        else
            log('INFO:  No Pre-all-test method (' || g_pretest_setup_method || ') found.', 0, LOG_LEVEL_SUPER);
        end if;
        
        --Check for pre-test setup method
        l_setup_exists    := method_exists(in_package_name, g_setup_method);        
        if (not l_setup_exists) then
            p('WARNING:  No setup method (' || g_setup_method || ') found.');
        end if;

        --Check for post-test teardown method.
        l_teardown_exists := method_exists(in_package_name, g_teardown_method);        
        if (not l_teardown_exists) then
            p('WARNING:  No teardown method (' || g_teardown_method || ') found.');
        end if;
    
        --Run all the tests or the one test that was specified.  Calling the
        --setup and teardown methods before and after each test ran.
        for i in 1..g_private_test_methods.count loop
            if(upper(g_private_test_methods(i).test_name) not in (g_pretest_setup_method, 
                                                                  g_post_test_teardown_method,
                                                                  g_teardown_method, 
                                                                  g_setup_method) 
              and
               upper(g_private_test_methods(i).test_name) = nvl(upper(in_test_name), upper(g_private_test_methods(i).test_name))
            )then                    
                set_unit(i);
                g_expected_sqlcode := null;
                                    
                if(g_log_level > LOG_LEVEL_LOW)then
                    print_unit_test_name;
                end if;
                
                if (l_setup_exists) then
                    log('[Setup]', TEST_INDENT, LOG_LEVEL_SUPER);
                    run_method(in_package_name || '.' || g_setup_method);
                end if;
                    
                run_method(in_package_name || '.' || g_private_test_methods(i).test_name);                
                g_test_count := g_test_count + 1;

                if (l_teardown_exists) then
                    log('[Teardown]', TEST_INDENT, LOG_LEVEL_SUPER);
                    run_method_no_trap(in_package_name || '.' || g_teardown_method);
                end if;
            end if;                                
        end loop;    

        --Check for post-run teardown method.
        if (method_exists(in_package_name, g_post_test_teardown_method)) then
            log('[Post-run teardown]', 0, LOG_LEVEL_SUPER);
            run_method_no_trap(in_package_name || '.' || g_post_test_teardown_method);
        else
            log('INFO:  No Post-all-test method (' || g_post_test_teardown_method || ') found.', 0, LOG_LEVEL_SUPER);
        end if;            
    end;    
-----------------
--Public Asserts
-----------------
    -----------------------------------------------------------------------------
    --See spec
    -----------------------------------------------------------------------------    
    procedure assert(in_bool in boolean, in_msg in varchar2) is
    begin
        if (not nvl(in_bool, false)) then
            fail(in_msg);
        else
            log(ASSERT_PASS_MSG||':  '||in_msg, TEST_INDENT, 3);
        end if;
    end;

    -----------------------------------------------------------------------------
    --See spec
    -----------------------------------------------------------------------------    
    procedure assert(in_got in number, in_expected in number, in_msg in varchar2) is
    begin
        assert_eq(in_got, in_expected, in_msg);
    end;

    -----------------------------------------------------------------------------
    --See spec
    -----------------------------------------------------------------------------    
    procedure assert(in_got in varchar2, in_expected in varchar2, in_msg in varchar2) is
    begin
        assert_eq(in_got, in_expected, in_msg);
    end;

    -----------------------------------------------------------------------------
    --See spec
    -----------------------------------------------------------------------------    
    procedure assert_eq(in_got in number, in_expected in number, in_msg in varchar2) is
    begin
        if (in_got is not null and in_expected is null or in_got is null and in_expected is not null or
           in_got <> in_expected) then
            fail(in_msg || '[' || 'Expected "' || in_expected || '" but got "' || in_got || '"]');
        else
            log(ASSERT_PASS_MSG||':  '||in_msg, TEST_INDENT, 3);
            log('[Expected "' || in_expected || '" but got "' || in_got || '"]'||in_msg, TEST_INDENT + 1, 4);            
        end if;
    end;

    -----------------------------------------------------------------------------
    --See spec
    -----------------------------------------------------------------------------    
    procedure assert_eq(in_got in varchar2, in_expected in varchar2, in_msg in varchar2) is
    begin
        if (in_got is not null and in_expected is null or in_got is null and in_expected is not null or
           in_got <> in_expected) then
            fail(in_msg || '[' || 'Expected "' || in_expected || '" but got "' || in_got || '"]');
        else
            log(ASSERT_PASS_MSG||':  '||in_msg, TEST_INDENT, 3);
            log('[Expected "' || in_expected || '" but got "' || in_got || '"]'||in_msg, TEST_INDENT + 1, 4);
        end if;
    end;

    -----------------------------------------------------------------------------
    --See spec
    -----------------------------------------------------------------------------    
    procedure assert_ne(in_got in varchar2, in_expected in varchar2, in_msg in varchar2) is
    begin
        if ((in_got is null and in_expected is null) or (in_got = in_expected)) then
            fail(in_msg || '[' || 'Expected "' || in_expected || '" to not equal "' || in_got || '"]');
        else
            log(ASSERT_PASS_MSG||':  '||in_msg, TEST_INDENT, 3);
            log('[Expected "' || in_expected || '" but got "' || in_got || '"]'||in_msg, TEST_INDENT + 1, 4);            
        end if;
    end;

    -----------------------------------------------------------------------------
    --See spec
    -----------------------------------------------------------------------------    
    procedure assert_gt(in_got in number, in_threshold in varchar, in_msg in varchar2) is
    begin
        if(in_got is null or in_threshold is null or in_got > in_threshold)then
            fail(in_msg || ' [' || 'Expected "' || in_got || '" to be greater than "'|| in_threshold || '"]');
        else
            log(ASSERT_PASS_MSG||':  '||in_msg, TEST_INDENT, 3);
            log('[Expected "' || in_threshold || '" but got "' || in_got || '"]'||in_msg, TEST_INDENT + 1, 4);            
        end if;
    end;
    
    -----------------------------------------------------------------------------
    --See spec
    -----------------------------------------------------------------------------    
    procedure pending(in_msg in varchar2 default null) is
    begin
        log(g_private_test_methods(g_cur_unit).test_name || ' is PENDING:  ' || in_msg, TEST_INDENT);
        g_pending_count := g_pending_count + 1;
    end;

    -----------------------------------------------------------------------------
    --See spec
    -----------------------------------------------------------------------------    
    procedure set_expected_error_sqlcode(in_sqlcode in number)is
    begin
        g_expected_sqlcode := in_sqlcode;
    end;
    
-------------------
--Public Run tests
-------------------

    -----------------------------------------------------------------------------
    --runs all methods in the passed in package that start with the test prefix.  
    --These methods are run in the order that they are declared.  This starts a new 
    --test for the package and each method is a unit.
    --
    --See spec for more info
    -----------------------------------------------------------------------------    
    procedure test_package(in_pkg_name in varchar2, in_test_name in varchar2 default NULL) is
        l_pkg_name varchar2(100);
        l_count    number;
    begin     
        l_pkg_name := upper(in_pkg_name);
        select count(1)
          into l_count
          from all_objects
         where object_name = upper(l_pkg_name)
           and object_type = 'PACKAGE';
    
        if (l_count = 0) then
            p('Could not find package ' || in_pkg_name);
        else
            make_tests_public(l_pkg_name);
            init_test(l_pkg_name);
            
            run_tests_as_a_test_package(l_pkg_name, in_test_name);
                
            put_old_spec_back;
            end_test;
        end if;
    exception
        when others then
            put_old_spec_back;
            dbms_output.put_line(sqlerrm);
            dbms_output.put_line(dbms_utility.format_error_backtrace);
            raise;
    end;

    -----------------------------------------------------------------------------    
    --Runs all tests in all test packages owned by the specified user.
    -----------------------------------------------------------------------------    
    procedure test_user(in_user in varchar2)
    is
        cursor c_test_packages is
            select distinct(object_name) pkg_name 
              from all_procedures 
             where object_type = 'PACKAGE' 
               and owner = upper(in_user) 
               and object_name like (g_test_package_prefix||'%');

        l_fail_count        number := 0;
        l_test_count        number := 0;
        l_pending_count     number := 0;
        l_pkgs_tested       number := 0;
    begin
        for rec in c_test_packages loop
            test_package(rec.pkg_name);
            
            l_fail_count := l_fail_count + g_fail_count;
            l_pending_count := l_pending_count + g_pending_count;
            l_pkgs_tested := l_pkgs_tested + 1;
            l_test_count := l_test_count + g_test_count;
            dbms_output.put_line('---------------------------------');
        end loop;
        
        dbms_output.put_line('');
        dbms_output.put_line('Tested '||l_pkgs_tested||' packages.');
        dbms_output.put_line('Total Tests:    '||l_test_count);
        dbms_output.put_line('Total Failed:   '||l_fail_count);
        dbms_output.put_line('Total Pending:  '||l_pending_count);
    end;

--------------
--Accessors
--------------
    -----------------------------------------------------------------------------
    --See spec
    function get_test_count return number
    is
    begin
        return g_test_count;
    end;
    -----------------------------------------------------------------------------
    --See spec
    function get_pending_count return number
    is
    begin
        return g_pending_count;
    end;
    -----------------------------------------------------------------------------
    --See spec
    function get_fail_count return number
    is
    begin
        return g_fail_count;
    end;
    -----------------------------------------------------------------------------
    --See spec
    function get_package_prefix return varchar2
    is
    begin
        return g_test_package_prefix;
    end;
    -----------------------------------------------------------------------------
    --See spec
    function get_method_prefix return varchar2
    is
    begin
        return g_test_method_prefix;
    end;        
    -----------------------------------------------------------------------------
    --See spec
    procedure set_log_level(in_log_level in number)
    is
    begin
        g_log_level := in_log_level;    
    end;
    ---------------------------------------------------------------------------
    --See spec
    function get_current_test_name return varchar2
    is
        l_return varchar2(200) := null;
    begin
        if(g_cur_unit > 0)then
            l_return :=  g_private_test_methods(g_cur_unit).test_name;
        end if;
        
        return l_return;
    end;    
    ---------------------------------------------------------------------------
    --See spec
    function get_current_test_comment return varchar2
    is
        l_return varchar2(200) := null;
    begin
        if(g_cur_unit > 0)then
            l_return :=  g_private_test_methods(g_cur_unit).comments;
        end if;
        
        return l_return;
    end;        
end xut;
/
