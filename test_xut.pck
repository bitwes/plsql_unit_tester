/* 
Testing the test tester for testing goodness.
  In order to test xut this package should be tested twice.  This 
  will ensure that all globals are working properly and that xut will
  recompile the old package properly.
  
  To do so, run the following code and verify the summary section
  of both runs.
  
    
begin
  xut.test_package('<PKG_NAME>');
  dbms_output.put_line('#################################################');
  xut.test_package('<PKG_NAME>');
end;
*/
create or replace package test_xut is
  procedure raises_neg_20001;  

  procedure does_nothing;


     procedure raise_no_data_found
     ;


     
     end    test_xut     ;    
     

--Leave the line above alone, it makes sure that 
--the parser thandles everything ok.     


    
     --These are some comments to make sure that the 
     --parser handles things ok
     
     
/
create or replace package body test_xut is
    g_fail_count          number := 0;
    g_setup_call_count    number := 0;
    g_teardown_call_count number := 0;
    --The pre run setup should only be called once.  This is checked
    --to be sure that it is not called more than once.  This helps
    --ensure that the pre run setup isn't called as a test.
    g_pre_run_setup_called_already  boolean := false;
            
    --reset by testteardown, makes sure that setup not
    --called more than once per test.  Helps catch accidently
    --calling the setup method as a test.    
    g_setup_called_already  boolean := false;

   
    procedure print_expected_fail(in_num in number) is
    begin
        g_fail_count := g_fail_count + in_num;
        xut.p('<' || in_num || ' expected failures>', 1);
    end;

    procedure testprerunsetup is
    begin
        xut.print('## pretest setup ran');
        --reset globals at the start of each 
        --testing run in case this is run
        --multiple times in a row such as when
        --testing parser/compilation logic.
        g_fail_count          := 0;
        g_setup_call_count    := 0;
        g_teardown_call_count := 0;
        xut.assert(g_pre_run_setup_called_already = false, 'The pre run setup method should only be called once per testing run.');
        g_pre_run_setup_called_already := true;
        xut.set_log_level(xut.LOG_LEVEL_HIGHER);
    end;

    procedure testpostrunteardown is
    begin
        xut.print('## posttestteardown ran');
    end;

    procedure testsetup is
    begin
        if(g_setup_called_already)then
            xut.assert(false, 'Setup has already been called for this test.');
        end if;
        
        g_setup_called_already := true;            
        g_setup_call_count := g_setup_call_count + 1;
    end;

    procedure testteardown is
    begin
        g_teardown_call_count := g_teardown_call_count + 1;
        g_setup_called_already := false;
    end;

--!-----------------------------------------------
--!The following tests should fail.  The number
--!of times they fail should be printed.
--!-----------------------------------------------

    procedure test_fail_assert is
    begin
        print_expected_fail(1);
        xut.assert(false, 'This should fail!');
    end;

    procedure test_fail_assert_eq_num is
    begin
        print_expected_fail(3);
        xut.assert_eq(1, 2, 'Should fail 1 != 2');
        xut.assert_eq(null, 2, 'Should fail null != 2');
        xut.assert_eq(2, null, 'Should fail 2!= null');
    end;

    procedure test_fail_assert_eq_var is
    begin
        print_expected_fail(3);
        xut.assert_eq('asdf', null, 'Should fail ''asdf'' != null');
        xut.assert_eq(null, 'asdf', 'Should fail null != ''asdf''');
        xut.assert_eq('asdf', 'qwert', 'Should fail ''asdf'' != ''qwert''');
    end;

    procedure test_fail_due_to_error is
    begin
        print_expected_fail(1);
        raise_application_error(-20001, 'This error should cause test to fail.');
    end;

    procedure test_fail_assert_errors is
    begin
        print_expected_fail(1);
        xut.assert_errors('test_xut.does_nothing', -20001);
    end;

    procedure test_fail_asrt_errors_bad_err is
    begin
        print_expected_fail(1);
        xut.assert_errors('test_xut.raises_neg_20001', -20222);
    end;

    procedure test_fail_assert_no_error is
    begin
        print_expected_fail(1);
        xut.assert_no_error('test_xut.raises_neg_20001');
    end;

    procedure test_fail_assert_ne_text is
    begin
        print_expected_fail(1);
        xut.assert_ne('asdf', 'asdf', 'asdf = asdf, so this should faile.'); 
    end;
    
    procedure test_fail_assert_ne_txt_null is
    begin
        print_expected_fail(1);
        xut.assert_ne(null, null, 'Null = null so this should fail');
    end;
    
    procedure test_fail_assert_gt is
    begin
        print_expected_fail(1);
        xut.assert_gt(5, 10, 'Five is not greater than 10, this should fail.');
    end;

    procedure test_fails_assert_gt_null is
    begin
        print_expected_fail(2);     
        xut.assert_gt(null, 10, 'Null is greater than nothing.');
        xut.assert_gt(10, null, 'Null is less than nothing.');
    end;
    
    --#Test that, when having an expected error, that an unexpected
    --#error causes this to fail.
    procedure test_has_expected_gets_unex
    is
    begin
        print_expected_fail(1);
        xut.set_expected_error_sqlcode(-1);
        raise_application_error(-20001, 'unexpected error');
    end;
    
    --#Test that, when having an expected error, if no error occurs
    --#that the test fails.
    procedure test_has_expected_gets_none
    is
    begin
        print_expected_fail(1);
        xut.set_expected_error_sqlcode(-123);
    end;

--!--------------------------------------
--!The following tests should pass.
--!--------------------------------------

    procedure test_pass_assert is
    begin
        xut.assert(true, 'This better pass.');
    end;

    procedure test_pass_assert_eq_num is
        num1 number := null;
        num2 number := null;
    begin
        xut.assert_eq(num1, num2, 'Should pass.');
        num1 := 1;
        num2 := 1;
        xut.assert_eq(num1, num2, 'Should pass.');
    end;

    procedure test_pass_assert_eq_var is
        str1 varchar2(10) := null;
        str2 varchar2(10) := null;
    begin
        xut.assert_eq(str1, str2, 'Should pass.');
        str1 := 'asdf';
        str2 := 'asdf';
        xut.assert_eq(str1, str2, 'Should pass.');
    end;

    procedure test_pass_assert_errors is
    begin
        xut.p('If this fails, test_xut may need to be recompiled.  Check that FIRST', 2);
        xut.assert_errors('test_xut.raises_neg_20001', -20001);
    end;

    procedure test_pass_assert_no_error is
    begin
        xut.assert_no_error('test_xut.does_nothing');
    end;

    procedure test_pending_with_message is
    begin
        xut.pending('This is a pending test.');
        xut.assert_eq(xut.get_pending_count, 1, 'There should be one pending test.');
    end;

    procedure test_pending_no_message is
    begin
        xut.pending;
        xut.assert_eq(xut.get_pending_count, 2, 'There should be two pending test.');
    end;
    
    --If the passed in package does not exist then a message should be printed
    --instead of an error being raised.
    procedure test_not_fail_when_pkg_dne is
    begin        
        xut.test_package('this_pkg_dne_in_the_db');
        xut.assert(true, 'Pass if we make it here.');
    exception
        when others then
            xut.assert(false, 'Should not have errored.');
    end;
    
    procedure test_pass_assert_ne_text is
    begin
        xut.assert_ne('asdf', 'qwert', 'asdf <> qwert, so this should pass.');     
    end;
    
    procedure test_pass_assert_ne_txt_null is
    begin
        xut.assert_ne(null, 'asdf', 'NULL <> asdf so this should pass.');
        xut.assert_ne('asdf', null, 'asdf <> NULL so this should pass.');
    end;    
    
    procedure test_pass_gt is
    begin
        xut.assert_gt(10, 5, 'Ten should be greater than 5, this should pass.');
    end;
    
    --#Setting expected error causes erroring code to pass.
    procedure test_expected_error is
    begin
        xut.set_expected_error_sqlcode(-20001);
        raise_application_error(-20001, 'expected error');
    end;
    
    --#Setting expected error to an oracle code works 
    procedure test_expected_with_ora_err is
    begin
        xut.set_expected_error_sqlcode(100);
        raise_no_data_found;        
    end;
--***************************************************************************--
--This section contains examples of valid test method declerations.  Invalid
--declerations cannot be included here or xut won't be able to compile the
--package.  Whenever a problem with the parser is discovered a test
--should be added here.
--***************************************************************************--
--!------------------------------------------------
--!The following tests just make sure that the
--!logic that parses out test methods from body
--!works as expected.
--!------------------------------------------------

    procedure test_is_on_same_line is
    begin
        null;
    end;

    procedure test_comment_on_line --this is a comment
     is
    begin
        null;
    end;

    procedure test_test_test_the_test is
    begin
        null;
    end;
    
    procedure test_is_next_line_no_spc_end
    is
    begin
        null;
    end;
    
    procedure test_is_next_line_space      
    is
    begin
        null;
    end;
    
    --#hello world
    procedure test_comment_simple
    is
    begin
        xut.assert(xut.get_current_test_comment, 'hello world', 'Should have set the comment to hello world');
    end;
    
    --#there is a trailing space here that should be stripped off. 
    procedure test_comment_trail_space
    is
    begin
        xut.assert(xut.get_current_test_comment, 'there is a trailing space here that should be stripped off.', 'Should have set the comment to hello world');
    end;
    
    --#hello
    --#world.
    procedure test_2_line_comment
    is
    begin
        xut.assert(xut.get_current_test_comment, 'hello world.', 'The multi-line comment should have been parsed into a single line.');
    end;
    
    --it only picks up the lines that start with dash dash pound
    --#1
    --so it should just concat them together.
    --#2
    --and skip the rest of the lines.
    procedure test_seperated_comments
    is
    begin
        xut.assert(xut.get_current_test_comment, '1 2', 'The multi-line comment should have been parsed into a single line.');    
    end;
--***************************************************************************--  
--Not a test, displays summary info
--***************************************************************************--
procedure test_disp_summary_disclaimer is
begin
    xut.p('----------------------------------------');
    xut.print('Summary (this section should contain NO errors)');    
    --setup - 1 == teardown  since the teardown for THIS test 
    --has not yet been run.  when neither are run though it gets messy since they are equal
    --(both are 0) but we are comparing them as if setup shoud be greater.  Other errors
    --occur when they are not called though, and these should be addressed first.
    xut.p('  Setup called:     ' || (g_setup_call_count - 1));
    xut.p('  Teardown called:  ' || g_teardown_call_count);
    xut.assert(g_setup_call_count > 0, 'Setup was called.');
    xut.assert(g_teardown_call_count > 0, 'Teardown was called.');
    xut.assert(g_setup_call_count - 1 = g_teardown_call_count,
               'Setup and teardown calls should be equal.  These will also not equal if they were never called.');
    xut.p('  2 tests should be pending');
    xut.assert(xut.get_pending_count = 2, 'There should be two pending tests');
    xut.p('  ' || g_fail_count || ' tests should have failed.');    
    xut.assert(xut.get_fail_count, g_fail_count, 'Expected fail count matches XUT fail count');    
    xut.p('----------------------------------------');
end;
--***************************************************************************--

    --------------------------
    --Public methods
    --------------------------
    procedure raises_neg_20001 is
    begin
        raise_application_error(-20001, 'This error is raised on purpose.');
    end;

    procedure does_nothing is
    begin
        null;
    end;
    
    procedure raise_no_data_found is
        type t_array is table of varchar2(100) index by binary_integer;
        l_array     t_array;
        l_dummy     varchar2(100);
    begin
        l_dummy := l_array(100);
    end;
end test_xut;
/
