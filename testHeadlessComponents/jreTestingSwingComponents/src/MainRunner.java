import java.util.List;


public class MainRunner {

    public static TestArgumentParser parser = new TestArgumentParser();

    public static void main(String[] args) {
        boolean err = false;
        TestArgumentParser parser = new TestArgumentParser();
        parser.parseDisplayTestArgs(args);
	SwingTestUtils tu = new SwingTestUtils(parser);
	try {
	    err = tu.testComponents();
	} catch (Error e) {
            e.printStackTrace();
            err = true;
            System.err.println("Unexpected error");
        } catch (Exception ex) {
            ex.printStackTrace();
            System.err.println("Unexpected exception");
            err = true;
        }
        if (err) {
            System.out.println("Exiting with 1");
            System.exit(1);
        } else {
            System.out.println("Exiting with 0");
            System.exit(0);
        }
    }
}
