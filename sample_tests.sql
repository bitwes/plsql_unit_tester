create or replace package body sample_tests is
-------------------------------------------------------------------------------
--This is a sample package to show how to create a test package.  To run
--the tests run the following;
--  xut.test_package('sample_tests');
--or, to run a single test
--  xut.test_package('sample_tests', 'test_one');
--
--Creating Tests
-----------------
--Create tests by making procedures w/o any parameters that have the test
--prefix TEST_ (not case sensative).
--
--Since PL/SQL methods are limited to 30 characters it can be difficult to make
--a name that adequately explains what the test is testing.  You can add specially
--formatted comments that will display extra information when the tests run.
--Any comment above the procedure decleration that starts with a --# will be 
--displayed.  See the tests for examples.
--  
--You can also use the --! comment to output headings.
--
--Optional Special methods
---------------------------
--You can also create methods that will be run before/after all the tests
--and before each individual test (setup and teardown methods).  These methods
--are not required by can greatly simplify your code in many cases.
--
--These methods are:
--  TESTPRERUNSETUP
--  TESTPOSTRUNTEARDOWN
--  TESTSETUP
--  TESTTEARDOWN
------------------------------------------------------------------------------
    --Methods that do not start with the prefix, or are not one of the 
    --setup/teardown methods will not be called during the tests.
    function get_number_5 return number
    is
    begin
        return 5;
    end;

    --This is run before any of the tests are run.  Perform setup and 
    --initializtions here
    procedure TESTPRERUNSETUP is
    begin
        --This is just a sample, you wouldn't want to do this.  But
        --this also illustrates the log level.
        xut.set_log_level(xut.LOG_LEVEL_SUPER);
        xut.p('pre-run setup.');
    end;

    --This will run after all the tests have run.  Perform any clean-up
    --needed here.
    procedure TESTPOSTRUNTEARDOWN is    
    begin
        xut.p('post-run teardown');
    end;

    --This runs before each test is run.  Do any common data population
    --or initialization here.
    procedure TESTSETUP is
    begin
        xut.p('Runs before each test.', 2);
    end;

    --This runs after each test is run.  Do any clean-up.  A common taks
    --is to perform a rollback so no changes made to the DB are committed.
    procedure TESTTEARDOWN is
    begin
        xut.p('Runs after each test.', 2);
        rollback;
    end;

--!--__--__--__--__--__--__--__--__
--!Look...a heading
--!********************************

    --#This is the first simple test.
    procedure test_one 
    is
    begin
        xut.assert(1 = 1, 'Example of using assert with a boolean');
    end;
    
    --Another test.    
    procedure test_show_failure
    is
    begin
        --Assert that verifys that the first parameter is what you thought it
        --would be (the 2nd parameter) and a message.
        xut.assert(get_number_5, 6, 'This will fail because 6 is clearly not 5.');
    end;
    
    --#This shows the simplest test stub.
    procedure test_pending
    is
    begin
        xut.pending;
    end;

    
    --#You can also send pending a message to display.
    procedure test_pending_message
    is
    begin
        xut.pending('This is a test that is yet to be implemented.');
    end;
    
    procedure test_assert_varchar2
    is
    begin
        xut.assert('asdf', 'asdf', 'These are the same');
    end;

--!--------------------------------------------------------
--!Tests checking for expected and unexpected exceptions
--!--------------------------------------------------------    
    procedure test_check_for_an_exception
    is
    begin
        xut.set_expected_error_sqlcode(-20001);
        raise_application_error(-20001, 'This error is expected');
    end;
    
    procedure test_get_different_exception
    is
    begin
        xut.set_expected_error_sqlcode(-20001);
        raise_application_error(-20002, 'This error is unexpected');
    end;
    
    procedure test_wasnt_looking_for_error
    is
    begin
        xut.assert(1, 1, 'I got a 1, just like I always wanted.');
        raise_application_error(-20003, 'ERRORED');
    end;
end sample_tests;
/
